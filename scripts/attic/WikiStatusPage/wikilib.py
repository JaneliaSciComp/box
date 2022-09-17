#!/usr/bin/python
"""

this is a library of useful wiki routines; it's derived from
my earlier "j2clib.py", which was originally written to 
support our Joomla to Confluence ('j2c') migration in 2007


djo, 8/09

"""


# ------------------------- imports -------------------------
# standard lib
import getpass
import mimetypes
import os
import re
import sys
import time
import xmlrpclib

# effbot's element tree for the xml:
#import elementtree.ElementTree as ET


# ------------------------- constants -------------------------
# default url: my test wiki
testwikiurl = "http://olbris-ws:8080/wiki/rpc/xmlrpc"
productionwikiurl = "http://wiki/wiki/rpc/xmlrpc"
externalwikiurl = "https://wiki.janelia.org/wiki/rpc/xmlrpc" 
openwikiurl = "http://openwiki.janelia.org/wiki/rpc/xmlrpc"



# ------------------------- transformperms() -------------------------
def transformperms(permlist):
    """
    transform a list of permissions returned by getPermissionsList()
    so that it looks like the input to setPermissionsList(); sort them
    
    intention is that they will then be comparable
    
    input: permissions list
    output: reformatted perms list
    """
    
    # input form is: list of {'lockedBy': 'some group', 'lockType': 'View'}
    # output should be list of {'groupName': 'some group', 'type': 'Edit'}
    
    outlist = []
    
    for perm in permlist:
        outperm = {}
        for key in perm:
            if key == 'lockedBy':
                # this is a hack to distinguish users and groups; for us,
                #   hyphen always means group
                if '-' in perm[key]:
                    newkey = 'groupName'
                else:
                    newkey = 'userName'
            elif key == 'lockType':
                newkey = 'type'
            else:
                # I don't think there are other possibilities, but if so,
                #   copy them over as-is
                newkey = key
            outperm[newkey] = perm[key]
        outlist.append(outperm)
    
    outlist.sort()
    return outlist
    
    # end transformperms()

# ------------------------- updatepages -------------------------
def updatepages(wikiproxy, spacekey, pagetitle, contentdict):
    """
    in this case, "update" means "update or insert"
    
    input:  wiki proxy
            space key = where it's all happening
            page title = where to add new pages (will also be created if needed)
            dictionary of (title, content which is html) for new/updated pages
    output: none
    """
    
    # find and/or create the parent page
    if not wikiproxy.exists(spacekey, pagetitle):
        # if it's not there, create it under Home:
        parentpage = {}
        parentpage["title"] = pagetitle
        parentpage["space"] = spacekey
        parentpage["parentId"] = wikiproxy.getpage(spacekey, "Home")["id"]
        parentpage["content"] = "This is the parent page of some programatically added pages.\n"
        wikiproxy.storepage(parentpage)
    
    # pull back the full page whether new or old:
    parentpage = wikiproxy.getpage(spacekey, pagetitle) 
    parentid = parentpage["id"]
    
    # get current list of pages in the space; index the page
    #   structures by their title:
    pagelist = wikiproxy.getpages(spacekey)
    pagedict = {}
    for item in pagelist:
        pagedict[item["title"]] = item
    
    for key in contentdict:
        
        # if a page exists, modify its entry; otherwise, create
        #   a new page structure
        
        if key in pagedict:
            # we already have page summary; get full page:
            page = wikiproxy.getpage(spacekey, pagedict[key]["title"])
            actionword = "updated"
        else:
            # start a new page
            page = {}
            page["space"] = spacekey
            page["parentId"] = parentid
            page["title"] = key
            actionword = "inserted"
        
        page["content"] = "%s\n" % contentdict[key]
        
        try:
            result = wikiproxy.storepage(page)
            # print "%s page %s " % (actionword, key)
        except:
            # very lax here...just see what happened and move on:
            print "failed on page", key
            
            # if you want the error, use this:
            # raise
    
    # end updatepages()

# ------------------------- validtitle -------------------------
def validtitle(title):
    """
    is the input title valid for confluence?
    
    (while this probably should be part of the wikiproxy
    class, I want to be able to call it without opening
    the wiki connection)
    
    input: title
    output: boolean
    """
    
    # just a list of tests based on a Confluence error:
    
    if title[0] == "$" or title[0] == "~":
        return False
    if title[0:2] == "..":
        return False
    
    # here's most of the illegal characters:
    for c in [':', '@', '|', '^', '#', ';', '[', ']', '{', '}', '<', '>']:
        if c in title:
            return False
    
    # both slashes illegal, but hard to test for some reason...
    if chr(47) in title:
        return False
    if chr(92) in title:
        return False
    
    return True
    
    # end validtitle()

# ------------------------- class wikiproxy -------------------------
class wikiproxy(object):
    """
    use this class to manipulate a Confluence wiki via 
    xml-rpc
    
    note that pretty much any interesting data structures are 
    python dictionaries in xml-rpc
    
    self.token = login token
    self.s = the actual ServerProxy class
    self.sc = convience object through which all the calls go
    
    my method names reflect the corresponding Confluence remote
    methods (but all lower case)
    """
    # ......................... __init__ .........................
    def __init__(self, url=testwikiurl, user=None, pwd=None):
        """
        input: url of confluence xml-rpc
        output: none 
        """
        
        # we'll assume this works; it works for me, anyway
        if user is None:
            user = getpass.getuser()
        if pwd is None:
            pwd = getpass.getpass("Enter password: ")
        
        # connect and login:
        self.s = xmlrpclib.ServerProxy(url)
        self.sc = self.s.confluence1
        self.token = self.sc.login(user, pwd)
        
        self.starttime = time.time()
        
        # end __init__()
    
    # ......................... attachpagetitle .........................
    def attachpagetitle(self, title):
        """
        we're using section-based attachment pages, with names derived
        from the parent page for the section
        
        input:
        output:
        """
        
        # this is really inelegant but necessary:
        
        if title == "Environmental Health & Safety--Compliance":
            return "EH&S--C downloads"
        else:
            return "%s downloads" % title
        
        # end attachpagetitle()
    
    # ......................... exists .........................
    def exists(self, spacekey, pagetitle):
        """
        does the given page exists in the given space?
        
        input: space key and page title
        output: boolean
        """
        
        try:
            page = self.getpage(spacekey, pagetitle)
        except:
            return False
        
        return True
        
        # end exists()
    
    # ......................... getattachments .........................
    def getattachments(self, pageid):
        """
        get list of attachments
        
        input: page id
        output: list of attachments
        """
        
        return self.sc.getAttachments(self.token, pageid)
        
        # end getattachments()
    
    # ......................... addattachment .........................
    def addattachment(self, pageid, file, filename=None, mimetype=None, comment = ''):
        """
        add an attachment to a page
        
        input: page id, file object or file contents (str)
        output: attachment properties dict
        """
        
        if filename is None:
            try:
                filename = os.path.basename(file.name)
            except:
                raise ValueError, "Could not determine the name of the file."
        if mimetype is None:
            try:
                mimetype = mimetypes.guess_type(file.name)[0]
            except:
                raise ValueError, "Could not determine the MIME type of the file."
        props = {"fileName": filename, "contentType": mimetype, "comment": comment}
        
        try:
            if 'read' in dir(file):
                data = xmlrpclib.Binary(file.read())
            elif isinstance(file, str):
                data = xmlrpclib.Binary(file)
            else:
                raise ValueError
        except:
            raise ValueError, "Could not get the file contents."
        
        return self.sc.addAttachment(self.token, pageid, props, data)
    
    # ......................... getchildren .........................
    def getchildren(self, pageid):
        """
        get children of the page
        
        input: page id
        output: list of child pages
        """
        
        return self.sc.getChildren(self.token, pageid)
        
        # end getchildren()
    
    # ......................... getdescendents .........................
    def getdescendents(self, pageid):
        """
        get page summaries of all descendents of the page
        
        input: page id
        output: list of page summaries
        """
        
        return self.sc.getDescendents(self.token, pageid)
        
        # end getdescendents()
    
    # ......................... getpage .........................
    def getpage(self, spacekey, pagetitle):
        """
        input: space key and page title
        output: page stucture
        """
        
        return self.sc.getPage(self.token, spacekey, pagetitle)
        
        # end getpage()
    
    # ......................... getpages .........................
    def getpages(self, spacekey):
        """
        input: space key
        output: list of page summaries
        """
        
        return self.sc.getPages(self.token, spacekey)
        
        # end getpages()
    
    # ......................... getpagesiter() .........................
    def getpagesiter(self, spacekeylist=[]):
        """
        an iterator for retrieving all pages (not summaries) from 
        wiki spaces; pages you can't access are skipped
        
        input: list of spacekeyss to get pages from; default = []
                means "whole wiki"
        output: iterator returning one page at a time
        """
        
        if not spacekeylist:
            spacekeylist = [sp["key"] for sp in self.getspaces()]
        
        for spacekey in spacekeylist:
            for pagesummary in self.getpages(spacekey):
                title = pagesummary["title"]
                try:
                    page = self.getpage(spacekey, title)
                except:
                    # can't read it, skip and go on
                    continue
                yield page
        
        # end getpagesiter()
    
    # ......................... getspaces() .........................
    def getspaces(self):
        """
        input: none
        output: list of space summaries
        """
        
        return self.sc.getSpaces(self.token)
        
        # end getspaces()
    
    # ......................... logout .........................
    def logout(self):
        """
        end wiki session
        """
        
        self.sc.logout(self.token)
        
        endtime = time.time()
        print "time connected: %ss" % (endtime - self.starttime)
        
        # end logout()
    
    # ......................... removepage .........................
    def removepage(self, spacekey, pagetitle):
        """
        delete a single page
        """
        
        self.sc.removePage(self.token, self.getpage(spacekey, pagetitle)["id"])
        
        # end removepage()
    
    # ......................... removetree .........................
    def removetree(self, spacekey, pagetitle, removeparent=True):
        """
        remove all pages in the hierarchy below pagetitle
        
        input: space and page title; whether to remove top page or not
        """
        
        parentpage = self.getpage(spacekey, pagetitle)
        pagelist = self.getdescendents(parentpage["id"])
        
        for page in pagelist:
            self.removepage(spacekey, page["title"])
        
        if removeparent:
            self.removepage(spacekey, pagetitle)
        
        # end removetree()
    
    # ......................... storepage .........................
    def storepage(self, page):
        """
        add or update a page; for a new page, you must provide
        space, title, content; to update, also include id and
        version (probably gleaned from a getpage() call)
        
        input: page structure
        output: none
        """
        
        if not self.validtitle(page["title"]):
            raise ValueError("%s is not a valid Confluence page title" % page["title"])
        
        self.sc.storePage(self.token, page)
        
        # end storepage()
    
    # ......................... validtitle .........................
    def validtitle(self, title):
        """
        is the input title valid for confluence?
        """
        
        # call the stand-alone function:
        
        return validtitle(title)
        
        # end validtitle()
    
    # end class wikiproxy


