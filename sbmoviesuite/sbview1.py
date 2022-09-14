#!/usr/bin/env python
"""

This is the GUI tool for previewing fly movies in the avi, fmf, or sbfmf
format.  The single-panel version displays avi, fmf, and sbfmf movies 
as you'd expect.  

The four-panel version is intended to show the results of a conversion.  It
shows an avi movie, its converted sbfmf, the error between them, and the
foreground mask of the sbfmf.


djo, 4/08


"""


# ------------------------- imports -------------------------
# std lib
import os
import sys
import time


# GUI (non-visualization)
import Tkinter
import tkFileDialog as tkFD
import tkMessageBox as tkMB

# PIL
import Image
import ImageTk


# within our lib
from sbmovielib.movies import Avi
from sbmovielib.FlyMovieFormat import FlyMovie
from sbmovielib import Pmw


# ------------------------- constants -------------------------
# initial size of image window
initialsize = (650, 450)

# ------------------------- class SBViewer -------------------------
class SBViewer(object):
    """
    class for displaying movies
    """
    # ......................... __init__ .........................
    def __init__(self, debug=False):
        """
        input: debug flag
        """
        
        # ----- initialize variables
        
        self.debug = debug
        self.movie = None
        
        
        # ------------------------- start up the gui -------------------------
        self.root = Tkinter.Tk()
        Pmw.initialise(self.root)
        
        # I may need to scale down the window size at some point...
        #   on the other hand, probably the movies won't get that big
        # screenx = self.root.winfo_screenwidth()
        # screeny = self.root.winfo_screenheight()
        # self.root.geometry("%sx%s+50+50" % (screenx - 200, screeny - 200))
        
        
        # this image need not be exactly right size...it'll changae later;
        #   plus, could embed this image in a Pmw.ScrolledFrame, if the 
        #   movie is bigger than the screen
        
        self.imageframe = Tkinter.Frame(self.root)
        self.imageframe.pack(side='left', expand='yes', fill='both')
        
        self.filenamelabel = Tkinter.Label(self.imageframe,  text="")
        self.filenamelabel.pack(side='top', padx=5, pady=5)
        
        self.image = ImageTk.PhotoImage(Image.new('L', initialsize))
        self.imagelabel = Tkinter.Label(self.imageframe, image=self.image)
        self.imagelabel.pack(side='top', padx=10, pady=10)
        
        
        
        
        # ----- controls in right frame (at bottom, they can be squeezed
        #   offscreen by big movie frame size)
        
        buttonframe = Tkinter.Frame(self.root)
        buttonframe.pack(side='left', fill='y', expand='yes')
        
        
        Tkinter.Button(buttonframe, text="Open...", command=self.doopen).pack(side='top',
            padx=5, pady=5)
        
        
        
        # slider
        self.frameslider = Tkinter.Scale(buttonframe,
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
        
        # validation is minimal; easier to check against max frame
        #   when "return" is hit rather than reconfigure widget
        #   each time new movie is loaded
        self.frameentry = Pmw.EntryField(buttonframe,
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
        
        
        Tkinter.Button(buttonframe, text="Quit", 
            command=self.doquit).pack(side='bottom', padx=5, pady=5)
        if self.debug:
            Tkinter.Button(buttonframe, text="Pseudoshell", 
                command=self.doshell).pack(side='bottom')
        
        
        self.root.mainloop()
        
        # end __init__()
    
    # ......................... doframe .........................
    def doframe(self, value):
        """
        called when slider changes
        """
        
        if self.movie:
            self.showframe(int(value))
        
        # end doframe()
    
    # ......................... doopen .........................
    def doopen(self):
        """
        open a file
        """
        
        filename = tkFD.askopenfilename(parent=self.root, 
            title="File to open")
        if filename:
            basename, ext = os.path.splitext(filename)
            self.ext = ext
            if ext == ".avi":
                try:
                    self.movie = Avi(filename, fmfmode=True)
                except:
                    tkMB.showerror(title="Mea culpa",
                        message="I couldn't open %s; check for corruption in QT or WMP." %
                        (os.path.basename(filename)))
                    return
            elif ext == ".fmf" or ext == ".sbfmf":
                try:
                    self.movie = FlyMovie(filename)
                except:
                    tkMB.showerror(title="Alas, I have failed",
                        message="I couldn't open %s; check for corruption in Mtrax." %
                        (os.path.basename(filename)))
                    return
            else:
                tkMB.showerror(title="Do what now?", 
                    message="I don't know how to open %s; is it a movie file?" % 
                    os.path.basename(filename))
                return
            
            self.filenamelabel.configure(text="%s\t(%s x %s) x %s frames" %
                (filename, self.movie.get_width(), self.movie.get_height(), 
                    self.movie.get_n_frames()))
            
            self.frameslider.configure(to=self.movie.get_n_frames() - 1)
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
        
        if self.movie:
            frame = self.frameentry.getvalue()
            # could be nothing...
            if frame:
                frame = int(frame)
                nframes = self.movie.get_n_frames()
                frame = min(frame, nframes - 1)
                self.frameslider.set(frame)
        
        # end setframe()
    
    # ......................... showframe .........................
    def showframe(self, n):
        """
        show frame n
        """
        
        if self.movie:
            if 0 <= n < self.movie.get_n_frames():
                frame, stamp = self.movie.get_frame(int(n))
                # assumes image is a returned frame = numpy array;
                #   check type, and fix if it's wrong
                
                if frame.dtype != 'uint8':
                    frame = frame * (255. / frame.max())
                    frame = frame.astype('uint8')
                
                # need to reverse order of rows to match expected
                #   up/down orientation:
                image = Image.fromarray(frame[::-1])
                self.image = ImageTk.PhotoImage(image)
                self.showimage()
        
        # set slider to right location
        self.frameslider.set(n)
        
        # end showframe()
    
    # ......................... showimage .........................
    def showimage(self):
        """
        shows the PIL image in self.image
        """
        
        self.imagelabel.configure(image=self.image)
        
        # end showimage()
    
    # end class SBViewer



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
    function for script packaging purposes
    """
    
    temp = SBViewer(debug=False)
    # temp = SBViewer(debug=True)    
    
    # end main()
    

# ------------------------- script start -------------------------
if __name__ == "__main__":
    main()
