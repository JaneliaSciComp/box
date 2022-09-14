#!/usr/bin/env python
"""

This is the GUI tool for previewing fly movies in the avi, fmf, or sbfmf
format.  The single-panel version displays avi, fmf, and sbfmf movies 
as you'd expect.  

The four-panel version is intended to show the results of a conversion.  It
shows an avi movie, its converted sbfmf, the error between them, and the
foreground mask of the sbfmf.  This version does not show fmf movies.


If I had more time to do this properly, I'd unite the two into one
application, class, and/or file, as appropriate.


djo, 4/08


"""


# ------------------------- imports -------------------------
# std lib
import os
import sys

# numpy
import numpy as num

# GUI (non-visualization)
import Tkinter
import tkFileDialog as tkFD
import tkMessageBox as tkMB

# PIL
import Image
import ImageTk
from sbmovielib import Pmw


# within our lib
from sbmovielib.movies import Avi
from sbmovielib.FlyMovieFormat import FlyMovie


# ------------------------- constants -------------------------
# initial size of image window
initialsize = (650, 450)

# color and alpha for foreground overlay
#   (note that I can't get this to composite the way I want; even with
#   fgalpha in [0, 1], it comes out solid instead of translucent; I think
#   I must not understand the compositing model)
# fgcolor = (40, 160, 160)        # mid-dark gray-blue; prettier but not enough contrast
fgcolor = (250, 255, 10)        # bright yellow
fgalpha = 1


# ------------------------- class SBFourViewer -------------------------
class SBFourViewer(object):
    """
    show a movie and derivatives
    
    throughout the class, the windows will be numbered:
        
        ---------
        | 1 | 2 |
        ---------
        | 3 | 4 |
        ---------
    where:
        1 = avi
        2 = sbfmf
        3 = absolute error
        4 = sbfmf foreground pixels
    
    
    """
    # ......................... __init__ .........................
    def __init__(self, debug=False):
        """
        input: debug flag
        """
        
        # ----- initialize variables
        
        self.debug = debug
        
        # movie holds movies; image holds frame images; imagelable is
        #   the Tkinter.Label in which the images are placed
        self.movie = {
            1: None,
            2: None,
            3: None,
            4: None,
            }
        self.image = {}
        self.imagelabel = {}
        
        
        # ------------------------- start up the gui -------------------------
        self.root = Tkinter.Tk()
        Pmw.initialise(self.root)
        self.root.title("sbview4")
        
        # I may need to scale down the window size at some point...
        #   on the other hand, probably the movies won't get that big
        # screenx = self.root.winfo_screenwidth()
        # screeny = self.root.winfo_screenheight()
        # self.root.geometry("%sx%s+50+50" % (screenx - 200, screeny - 200))
        
        
        # this image need not be exactly right size...it'll change later;
        #   plus, could embed this image in a Pmw.ScrolledFrame, if the 
        #   movie is bigger than the screen
        
        self.leftframe = Tkinter.Frame(self.root)
        self.leftframe.pack(side='left', expand='yes', fill='both')
        
        # filename label
        self.filenamelabel = Tkinter.Label(self.leftframe,  text="")
        self.filenamelabel.pack(side='top', padx=5, pady=5)
        
        # top pane label
        toplabelframe = Tkinter.Frame(self.leftframe)
        toplabelframe.pack(side='top', fill='x', expand='yes')
        
        Tkinter.Label(toplabelframe,  text="avi").pack(side='left', fill='x', expand='yes')
        Tkinter.Label(toplabelframe,  text="sbfmf").pack(side='left', fill='x', expand='yes')
        
        # grid of images
        self.imageframe = Tkinter.Frame(self.leftframe)
        self.imageframe.pack(side='top')
        self.blank = ImageTk.PhotoImage(Image.new('L', initialsize))
        for pane, r, c in [(1, 0, 0), (2, 0, 1), (3, 1, 0), (4, 1, 1)]:
            self.image[pane] = self.blank
            self.imagelabel[pane] = Tkinter.Label(self.imageframe, image=self.image[pane])
            self.imagelabel[pane].grid(row=r, column=c)
        
        # bottom pane label
        bottomlabelframe = Tkinter.Frame(self.leftframe)
        bottomlabelframe.pack(side='top', fill='x', expand='yes')
        
        Tkinter.Label(bottomlabelframe,  text="error").pack(side='left', fill='x', expand='yes')
        Tkinter.Label(bottomlabelframe,  text="sbfmf bg & fg").pack(side='left', fill='x', expand='yes')
        
        
        # ----- controls in right frame (if you put them at the bottom, 
        #   they can be squeezed offscreen by big movies)
        rightframe = Tkinter.Frame(self.root)
        rightframe.pack(side='left', fill='y', expand='yes')
        
        
        # open button
        Tkinter.Button(rightframe, text="Open...", command=self.doopen).pack(side='top',
            padx=5, pady=5)
        
        # frame slider
        self.frameslider = Tkinter.Scale(rightframe,
            from_=0,
            to=0,
            length=300,
            orient="vertical",
            label="Frame",
            resolution=1,
            command=self.doframe,
            )
        self.frameslider.pack(side='top')
        self.frameslider.set(0)
        
        # go to frame entry field; validation is minimal; it's easier
        #   to check against max frame later rather than reconfigure widget
        #   each time new movie is loaded
        self.frameentry = Pmw.EntryField(rightframe,
            labelpos='n',
            label_text="Go to frame:",
            value=0,
            validate={'validator': 'integer',
                'min': 0,
                },
            modifiedcommand=self.setframe,
            entry_width=5,
            )
        self.frameentry.pack(side='top')
        
        # quit button
        Tkinter.Button(rightframe, text="Quit", 
            command=self.doquit).pack(side='bottom', padx=5, pady=5)
        
        # optional debugging widget
        if self.debug:
            Tkinter.Button(rightframe, text="Pseudoshell", 
                command=self.doshell).pack(side='bottom')
        
        
        self.root.mainloop()
        
        # end __init__()
    
    # ......................... doframe .........................
    def doframe(self, value):
        """
        called when slider changes
        """
        
        self.showframe(int(value))
        
        # end doframe()
    
    # ......................... doopen() .........................
    def doopen(self):
        """
        open movie files
        """
        
        # prompt for a file; if an avi or sbfmf is found, look for
        #   the corresponding one and try to open together
         
        filename = tkFD.askopenfilename(parent=self.root, 
            title="File to open")
        
        if not filename:
            return
        
        basename, ext = os.path.splitext(filename)
        if ext not in ['.avi', '.sbfmf']:
            tkMB.showinfo(title="Not quite what I'm expecting",
                message="Please choose an avi or sbfmf file")
            return
        
        if os.path.exists(basename + '.avi'):
            aviname = basename + '.avi'
        else:
            aviname = None
            self.movie[1] = None
            self.showimage(None, 1)
            self.showimage(None, 3)
        if os.path.exists(basename + '.sbfmf'):
            sbfmfname = basename + '.sbfmf'
        else:
            sbfmfname = None
            self.movie[2] = None
            self.showimage(None, 2)
            self.showimage(None, 3)
            self.showimage(None, 4)
        
        if aviname:
            try:
                self.movie[1] = Avi(aviname, fmfmode=True)
            except:
                tkMB.showerror(title="Mea culpa",
                    message="I couldn't open %s; check for corruption in QT or WMP." %
                    (os.path.basename(aviname)))
                return
        if sbfmfname:
            try:
                self.movie[2] = FlyMovie(sbfmfname)
                # also grab and reshape the bg frame:
                self.movie2bgcenter = self.movie[2].bgcenter.copy()
                self.movie2bgcenter.shape = (self.movie[2].get_height(),
                    self.movie[2].get_width())
                
                # save the bg frame as an image, too:
                if self.movie2bgcenter.dtype != 'uint8':
                    frame = self.movie2bgcenter * (255. / self.movie2bgcenter.max())
                    frame = frame.astype('uint8')
                
                # need to reverse order of rows to match expected
                #   up/down orientation:
                self.movie2bgimage = Image.fromarray(frame[::-1])
                
                # one more...also need a solid color image for later mask:
                self.solidimage = Image.new('RGB', self.movie2bgimage.size, fgcolor)
                
                
            except:
                tkMB.showerror(title="Alas, I have failed",
                    message="I couldn't open %s; check for corruption in Mtrax." %
                    (os.path.basename(sbfmfname)))
                # clean up: drop avi movie if it's there
                self.movie[1] = None
                return
        
        # use avi before sbfmf for label and slider setting:
        if aviname:
            labelname = aviname
            labelnum = 1
        else:
            labelname = sbfmfname
            labelnum = 2
        self.filenamelabel.configure(text="%s\t(%s x %s) x %s frames" %
            (labelname, self.movie[labelnum].get_width(), 
                self.movie[labelnum].get_height(),  self.movie[labelnum].get_n_frames()))
        
        self.frameslider.configure(to=self.movie[labelnum].get_n_frames() - 1)
        
        
        # show the first frame:
        self.showframe(0)
        
        # end doopen()
    
    # ......................... doshell .........................
    def doshell(self):
        """
        pseudoshell
        """
        
        myshell = PseudoShell(self)
        
        # end doshell()
    
    # ......................... doquit .........................
    def doquit(self):
        """
        quit
        """
        
        self.root.destroy()
        
        # end doquit()
    
    # ......................... setframe() .........................
    def setframe(self):
        """
        called on keypress "go to frame"; sets frame to new position
        
        input:
        output:
        """
        
        if self.movie[1] or self.movie[2]:
            frame = self.frameentry.getvalue()
            # could be nothing in entry...
            if frame:
                frame = int(frame)
                nframes = self.frameslider.cget("to")
                frame = min(frame, nframes)
                self.frameslider.set(frame)
        
        # end setframe()
    
    # ......................... showframe .........................
    def showframe(self, n):
        """
        show frame n in given pane 
        """
        
        # brute force this; get each frame and show as appropriate
        
        frame1 = None
        frame2 = None
        
        if self.movie[1]:
            if 0 <= n < self.movie[1].get_n_frames():
                frame, stamp = self.movie[1].get_frame(int(n))
                
                # save a copy for error image later 
                frame1 = frame.copy()
                
                self.showimage(frame, 1)
        
        if self.movie[2]:
            if 0 <= n < self.movie[2].get_n_frames():
                frame, stamp = self.movie[2].get_frame(int(n))
                
                # save a copy for error image later 
                frame2 = frame.copy()
                
                self.showimage(frame, 2)
                
                # frame 4 is foreground mask over background image; pass
                #   the one, it'll get composited with the other:
                frame = num.where(frame2 != self.movie2bgcenter, 0, fgalpha)
                self.showimage(frame, 4)
                
        
        if frame1 is not None and frame2 is not None:
            error = num.power(frame1 - frame2, 2)
            self.showimage(error, 3)
        
        # set slider to right location
        self.frameslider.set(n)
        
        # end showframe()
    
    # ......................... showimage .........................
    def showimage(self, frame, pane):
        """
        shows the input frame in appropriate pane
        
        input:  frame = numpy array
                pane = pane # to display in (top row: 1, 2; bottom: 3, 4)
        output: none
        """
        
        if frame is None:
            frame = num.zeros((initialsize[1], initialsize[0]), dtype='uint8')
        else:
            if frame.dtype != 'uint8':
                frame = frame * (255. / frame.max())
                frame = frame.astype('uint8')
        
        if pane == 4:
            # pane 4 is fore/background; needs clever compositing; the
            #   input frame is a mask:
            mask = Image.fromarray(frame[::-1])
            image = Image.composite(self.movie2bgimage, self.solidimage, mask)
        else:
            # usual grayscale frame
            # need to reverse order of rows to match expected
            #   up/down orientation:
            image = Image.fromarray(frame[::-1])
        
        # remember, must keep reference to image alive!
        self.image[pane] = ImageTk.PhotoImage(image)
        self.imagelabel[pane].configure(image=self.image[pane])
        
        # end showimage()
    
    # end class SBFourViewer

# ------------------------- class PseudoShell -------------------------
class PseudoShell:
    """
    A little widget that executes commands.  Inspired by a couple
    of examples by John E. Grayson in his Python/Tkinter book.
    """
    # ......................... __init__() .........................
    def __init__(self, parent):
        """
        input: parent = calling object
        output:
        """
        
        # store the caller so you can access it within debugger
        self.parent = parent
        
        # ------------------------- do the gui -------------------------
        # components: encompassing frame; scrolled text top,
        #   text entry field middle, buttons at the bottom
        self.root = Tkinter.Toplevel()
        self.root.title('Python pseudo-shell')
        
        self.outer = Tkinter.Frame(self.root)
        self.outer.pack(side='top', expand=1, fill='both')
        
        self.output = Pmw.ScrolledText(self.outer,
            vscrollmode='static',
            
            )
        self.output.pack(side='top', expand=1, fill='both', padx=10, pady=10)
        self.output.insert('end', "Python debugging shell\n\nType commands below,"
            " and they will be eval'd or exec'd.\n\n"
            "Variable 'me' is aliased to the calling widget.\n\n")
        
        
        self.input = Pmw.EntryField(self.outer,
            command=self.docommand,
            )
        self.input.pack(side='top', expand=1, fill='x', padx=10, pady=10)
        
        
        buttonframe = Tkinter.Frame(self.outer)
        buttonframe.pack(side='top', padx=10, pady=10)
        
        Tkinter.Button(buttonframe, text='Done', 
            command=self.dodone).pack(side='right', padx=4, pady=4)
        
        execbutton = Tkinter.Button(buttonframe, text='Exec', command=self.docommand)
        execbutton.bind('<Return>', self.docommand)
        execbutton.pack(side='right', padx=4, pady=4)
        
        
        # end __init__()
    
    # ......................... docommand() .........................
    def docommand(self):
        """
        input:
        output:
        """
        
        # for convenience: instead of typing "self.parent" constantly,
        #   use me:
        
        me = self.parent
        
        command = self.input.getvalue()
        self.input.component('entry').selection_range(0, 'end')
        self.input.component('entry').icursor('end')
        self.output.insert('end', ">>> %s\n" % command)
        
        # this is from Grayson:
        # try eval'ing it; if it works, keep result; 
        #   else, try exec'ing it:
        
        
        # for errors, try this (from docs):
        # traceback.print_exc(file=sys.stdout)
        
        
        try:
            result = eval(command, locals(), globals())
        except SyntaxError:
            try:
                exec command in locals(), globals()
                result = ''
            except:
                result = "error while exec'ing"
        except:
            result = "error while eval'ing"
        
        if result:
            # avoid a stupid string formatting error; since
            #   result could be a tuple, put it in a tuple:
            self.output.insert('end', "%s\n" % (result, ))
            self.output.component('text').see('end')
        
        # end docommand()
    
    # ......................... dodone() .........................
    def dodone(self):
        """
        input:
        output:
        """
        
        # destroy this window, not whole app
        self.root.destroy()
        
        # end dodone()
    
    # end class PseudoShell

# ------------------------- main() -------------------------
def main():
    """
    main function for script packaging
    """
    
    temp = SBFourViewer(debug=False)
    # temp = SBFourViewer(debug=True)
    
    # end main()
    
# ------------------------- script start -------------------------
if __name__ == "__main__":
    main()

