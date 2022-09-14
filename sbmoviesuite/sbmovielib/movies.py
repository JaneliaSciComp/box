"""

AVI reading routines

originally from movies.py in Mtrax; version checked out from svn on Apr 3 2008

modified by Donald J. Olbris for use in a stand-alone AVI to sbfmf 
convertor; basically, rip out the bare AVI class from the original file, and
be sure there aren't any outside dependencies that we don't need


original code is GPL (v2?), so therefore this is, too

djo, 4/08

"""




# movies.py
# JAB 5/10/07



import os
import struct
import sys

import numpy as num


class NoMoreFramesException (Exception): 
    pass


# ------------------------- class Avi -------------------------
"""
important alterations from version I received:
- allows fccHandler = "" or all nulls
- allows width to vary to match actual frame size (suspect that avi pads to 
    multiples of four?) (and let get_width return actual width)
- added various derived attributes to better masquerade as an FMF file
- added an "fmf" mode; in this mode, it reshapes array to same shape as fmf
    (row/column order swapped)
- added a seek() method

- I want to make this width change more transparent, but I keep
    running into related shape issues

- Avi class is still byte-order undefined, but at least it's read-only

"""
class Avi:
    """Read uncompressed AVI movies."""
    def __init__( self, filename, fmfmode=False ):
        
        self.fmfmode = fmfmode
        
        # need to open in binary mode to support Windows:
        # self.file = open( filename, 'r' )
        self.file = open( filename, 'rb' )
        self.read_header()
        
        # added to help masquerade as FMF file:
        self.filename = filename
        self.chunk_start = self.data_start
        # this is a mystery, but I think it's 8 for avi: seems to be offset
        #   from beginning of "chunk" to beginning of array data within chunk
        self.timestamp_len = 8
        if hasattr(self, "newwidth"):
            self.bytes_per_chunk = (self.height * self.newwidth) + self.timestamp_len
        else:
            self.bytes_per_chunk = self.buf_size + self.timestamp_len
        self.bits_per_pixel = 8 
    
    def read_header( self ):
        # RIFF header
        file_type, riff_size = struct.unpack( '4sI', self.file.read( 8 ) )
        assert file_type == 'RIFF'
        stream_type = self.file.read( 4 )
        assert stream_type == 'AVI '
        header_list, header_listsize, header_listtype = \
                     struct.unpack( '4sI4s', self.file.read( 12 ) )
        assert header_list == 'LIST' and header_listtype == 'hdrl'
        #size 4588 (fmf 1222)
        avi_str, avi_note = struct.unpack( '4sI', self.file.read( 8 ) )
        assert avi_str == 'avih'

        # AVI header
        avi_header = self.file.read( 56 )
        self.frame_delay_us, \
                          AVI_data_rate, \
                          padding_size, \
                          AVI_flags, \
                          self.n_frames, \
                          n_preview_streams, \
                          n_data_streams, \
                          avi_buf_size, \
                          self.width, \
                          self.height, \
                          self.time_scale, \
                          self.data_rate, \
                          self.start_time, \
                          self.AVI_chunk_size \
                          = struct.unpack( '14I', avi_header )
        #10000 100000000 0 16 100 0 1 1310720 1280 1024 100 10000 0 99
        if n_data_streams != 1:
            raise TypeError( "file must contain only one data stream" )
        if avi_buf_size != 0: self.buf_size = avi_buf_size

        # stream header
        stream_list, stream_listsize, stream_listtype = \
                     struct.unpack( '4sI4s', self.file.read( 12 ) )
        assert stream_list == 'LIST' and stream_listtype == 'strl'
        #size 4244 (fmf 1146)
        stream_str, stream_note = struct.unpack( '4sI', self.file.read( 8 ) )
        assert stream_str == 'strh'
        
        stream_header = self.file.read( 56 )
        fccType, \
                 fccHandler, \
                 stream_flags, \
                 priority, \
                 frames_interleave, \
                 stream_scale, \
                 stream_rate, \
                 stream_start, \
                 stream_length, \
                 stream_buf_size, \
                 stream_quality, \
                 stream_sample_size, \
                 x,y,w,h \
                 = struct.unpack( '4s4s10I4H', stream_header )
        #vids DIB  0 0 0 100 10000 0 99 1310720 100 0 0 0 1280 1024
        #vids DIB  0 0 0 1 50 0 301 235200 0 0 0 0 560 420
        
        if fccType != 'vids':
            raise TypeError( "stream type must be video" )
        # Reiser's current avi's have fccHandler = '\x00\x00\x00\x00'; I
        #   saw a reference that "" is also acceptable (djo)
        if fccHandler not in ['DIB ', '\x00\x00\x00\x00', ""]:
            raise ValueError( "video must be uncompressed; found fccHandler %s" % fccHandler)
            # raise TypeError( "video must be uncompressed" )
        if stream_buf_size != 0:
            if hasattr( self, 'buf_size' ):
                assert self.buf_size == stream_buf_size
            else:
                self.buf_size = stream_buf_size

        # bitmap header
        bmp_str, bmp_note = struct.unpack( '4sI', self.file.read( 8 ) )
        assert bmp_str == 'strf'

        bmp_header = self.file.read( 40 )
        self.bmp_size, \
                       bmp_width, \
                       bmp_height, \
                       bmp_planes, \
                       bmp_bitcount, \
                       crap, \
                       bmp_buf_size, \
                       xpels_per_meter, \
                       ypels_per_meter, \
                       color_used, \
                       color_important \
                       = struct.unpack( 'I2i2H6i', bmp_header )
        #40 1280 1024 1 8 0 1310720 0 0 256 0
        assert bmp_width == self.width and bmp_height == self.height
        if bmp_buf_size != 0:
            if hasattr( self, 'buf_size' ):
                assert self.buf_size == bmp_buf_size
            else:
                self.buf_size == stream_buf_size
        if not hasattr( self, 'buf_size' ):
            # just a guess -- should be OK if 8-bit grayscale
            self.buf_size = self.height * self.width

        # skip extra header crap
        movie_list = ''
        movie_listtype = ''
        while movie_list != 'LIST':
            s = ''
            EOF_flag = False
            while s.find( 'movi' ) < 0 and not EOF_flag:
                p = self.file.tell()
                s = self.file.read( 128 )
                '''
                # debug: could 'movi' fall across a the boundary of a 128 byte block?
                if p > 5200:
                    print "failed to find 'movi' as needed"
                    sys.exit()
                print "location:", p
                # print "data:", s
                '''
                if s == '': EOF_flag = True
            if EOF_flag: break
            self.file.seek( p )
            self.file.read( s.find( 'movi' ) - 8 )
            movie_list, movie_listsize, movie_listtype = \
                        struct.unpack( '4sI4s', self.file.read( 12 ) )
        assert movie_list == 'LIST' and movie_listtype == 'movi'

        # beginning of data blocks
        self.data_start = self.file.tell()
        
        # attempt to do frame-size vs width check here:
        this_frame_id, frame_size = struct.unpack( '4sI', self.file.read( 8 ) )
        if frame_size == self.width * self.height:
            # this is fine
            pass
        elif frame_size == 3 * self.width * self.height:
            # probably RGB, no good:
            raise TypeError( "movie must be grayscale" )
        else:
            # frame size doesn't match; for this exercise, pretend the height is 
            #   right and see if width is integral and within 10 of expected;
            #   if so, use that; otherwise, error (djo)
            # raise ValueError( "frame size %d doesn't make sense: movie must be 8-bit grayscale"%(frame.size) )
            if frame_size % self.height == 0:
                self.newwidth = frame_size / self.height
                if abs(self.newwidth - self.width) > 10:
                    raise ValueError("apparent new width = %d; expected width = %d"
                        % (self.height, self.newwidth))
            else:
                raise ValueError("apparent new width is not integral; mod = %d" % (frame_size % self.height))
        
        # end read_header()

    def get_frame( self, framenumber ):
        """Read frame from file and return as NumPy array."""
        if framenumber < 0: raise IndexError
        if framenumber >= self.n_frames: raise NoMoreFramesException
        
        # read frame from file
        self.file.seek( self.data_start + (self.buf_size+8)*framenumber )
        
        # rest of this function has been moved into get_next_frame(), which
        #   pretty much just reads without the seek
        
        return self.get_next_frame()
    
    def get_next_frame(self):
        """returns next frame"""
        
        currentseekloc = self.file.tell()
        
        this_frame_id, frame_size = struct.unpack( '4sI', self.file.read( 8 ) )
        if frame_size != self.buf_size:
            raise ValueError( "movie must be uncompressed" )
        if not hasattr( self, 'frame_id' ):
            self.frame_id = this_frame_id
        elif this_frame_id != self.frame_id:
            raise ValueError( "error seeking frame start: unknown data header" )
        frame_data = self.file.read( frame_size )
        
        # frame id: seems to be recorded from first frame, then compared at
        #   each successive frame; just a marker to be checked?
        
        # make frame into numpy array
        frame = num.fromstring( frame_data, num.uint8 )
        if frame.size == self.width*self.height:
            frame.resize( (self.height, self.width) )
        elif frame.size == self.width*self.height*3:
            #frame.resize( (self.height, self.width, 3) )
            #frame = imops.to_mono8( 'RGB8', frame )
            raise TypeError( "movie must be grayscale" )
        else:
            # frame size doesn't match; for this exercise, pretend the height is 
            #   right and see if width is integral and within 10 of expected;
            #   if so, use that; otherwise, error (djo)
            # raise ValueError( "frame size %d doesn't make sense: movie must be 8-bit grayscale"%(frame.size) )
            if frame.size % self.height == 0:
                self.newwidth = frame.size / self.height
                if abs(self.newwidth - self.width) < 10:
                    frame.resize((self.newwidth, self.height))
                else:
                    raise ValueError("apparent new width = %d; expected width = %d"
                        % (self.height, self.newwidth))
            else:
                raise ValueError("apparent new width is not integral; mod = %d" % (frame.size % self.height))
            
        # make up a timestamp based on the file's stated framerate
        
        # since we don't know the frame number, back it out from
        #   the file location (cleverly grabbed before we started
        #   reading the frame):
        
        framenumber = (currentseekloc - self.chunk_start) / self.bytes_per_chunk
        
        if self.frame_delay_us != 0:
            stamp = framenumber * self.frame_delay_us / 1e6
        elif self.time_scale != 0:
            stamp = framenumber * self.data_rate / float(self.time_scale)
        else:
            stamp = framenumber / 24
            # should raise warning or error here?
            # this might screw up playback, at least
        
        
        if self.fmfmode:
            # row/column order is swapped:
            shape = frame.shape
            frame.shape = (shape[1], shape[0])
        
        return frame, stamp
        
        # end get_next_frame()
    
    def close( self ):
        self.file.close()

    def get_n_frames( self ): 
        return self.n_frames
    
    def get_width( self ): 
        if hasattr(self, "newwidth"):
            return self.newwidth
        else:
            return self.width
    
    def get_height( self ): 
        return self.height
    
    def seek(self,frame_number):
        if frame_number < 0:
            frame_number = self.n_frames + frame_number
        seek_to = self.chunk_start+self.bytes_per_chunk*frame_number
        self.file.seek(seek_to)
    
    # end class Avi

if __name__ == "__main__":
    # if testing, look for a movie to open on command line
    if len(sys.argv) > 1:
        inputfilename = sys.argv[1]
    else:
        inputfilename = "/home/olbrisd/projects/mtrax/testdata/testmovie.avi"
    avi = Avi(inputfilename)
    print "read %s" % inputfilename
    print "size = %s x %s, %s frames" % (avi.get_width(),
        avi.get_height(), avi.get_n_frames())
    print "getting a frame"
    frame, stamp = avi.get_frame(1)
    print "frame size =", frame.size
    print "time stamp =", stamp
    print "frame_id =", avi.frame_id
    print
    print "try another frame"
    frame, stamp = avi.get_frame(1243)
    print "frame size =", frame.size
    print "time stamp =", stamp
    print "frame_id =", avi.frame_id
    print
    
