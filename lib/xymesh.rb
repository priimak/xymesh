# Open class Array and add methods 'abs' and 'cross_product'
class Array 
  # Calculate absolute value of the vector represented by this arrary
  def abs
    val=0
    self.each { |v|
      val = val + v**2
    }
    Math::sqrt(val)
  end

  # Calculate cross product of this and another vector repsented by array class.
  # Only applicable to vectors in 3D space.
  def cross_product(nv2)
    [self[1]*nv2[2]-self[2]*nv2[1], self[2]*nv2[0]-self[0]*nv2[2], self[0]*nv2[1]-self[1]*nv2[0]]
  end

  # Pretty print
  def to_s
    retval = StringIO.new
    retval << "["
    self.each { |e|
      retval << "#{e.to_s}, "
    }
    retval << "]"
    retval.string
  end
end # end of open class Array

module XYMesh

  require 'stringio'
  require "xymesh_aux"

  # This class represents two dimensional grid of points in the X-Y plane.
  # It performs externally provieded computations at these points and refines 
  # grid as nessesary by intorucing new points.
  class Grid2D
    
    # @return [Proc] external function that takes X,Y coordinates as parameters and return Z-value 
    # evaluated at this point.
    attr_accessor :computer

    # @return [LList] linked list of tiles. 
    # @see Tile
    attr_accessor :tiles

    # @return [Array] array of vetixes
    # @see Vertex
    attr_accessor :vtxs
    
    # @param x_min [Float] minimum value along the X-axis
    # @param x_max [Float] maximum value along the X-axis
    # @param n_x [Fixnum] number of segments along the X-axis, which gives n_x+1 points.
    # @param y_min [Float] minimum value along the Y-axis
    # @param y_max [Float] maximum value along the Y-axis
    # @param n_y [Fixnum] number of segments along the Y-axis, which gives n_y+1 points.
    # @param computer [Proc] external function to be evaluated at each point in the grid
    def initialize(x_min, x_max, n_x, y_min, y_max, n_y, computer=nil) 
      @x_min = x_min
      @x_max = x_max
      @n_x   = n_x
      @y_min = y_min
      @y_max = y_max
      @n_y   = n_y

      @min_val = 0
      @max_val = 0

      @vtxs  = []
      @tiles = LList.new

      @computer = computer

      # fill up vertexes
      idx=1
      dx=(x_max-x_min)/n_x.to_f
      dy=(y_max-y_min)/n_y.to_f
      (0..@n_y).to_a.each { |m|
        y=@y_min+dy*m
        (0..@n_x).to_a.each { |n|
          x=@x_min+dx*n
          vtx = Vertex.new(x, @y_min+dy*m, self)
          vtxs << vtx
          if( n > 0 && m > 0 )
            t=Tile.new(idx, idx-1, idx-n_x-2, self)
            t.connect(@tiles.append(t))

            t=Tile.new(idx, idx-n_x-2, idx-n_x-1, self)
            t.connect(@tiles.append(t))
          end
          idx = idx + 1
        }
      }
    end

    # @param tile [Tile] to be found in list of tiles tracked by this grid
    # @return [Fixnum] index of the tile in the list. Note that indexing starts with 1, not 0.
    def find_tile(tile)
      @tiles.each { |i,t| return i if t.value == tile }
    end

    # Perform mesh refinement by adding new vertex points to the tiles, curvature for 
    # which exceeds provied max_curvature value. To reach desired smoothness you need 
    # repeatedly call this function until amount of tiles that were split (returned by 
    # this function ) is zero. Alternatively you can call ''
    #
    # @param max_curvature [Float] curvature value below which we perform mesh refinement
    # @return [Fixnum] number of tiles that have been split
    def refine(max_curvature)
      refined = 0
      tiles_to_split=[]
      @tiles.each { |i, t| 
        if t.value.nvariance() > max_curvature
          tiles_to_split << t.value
        end
      }
      tiles_to_split.each { |t|
        t.split_and_evaluate() if t.inspect?
      }

      tiles_to_split.size
    end

    # Same as 'refine(max_curvature)', but will contain recursively until maximum tile 
    # curvature falls bellow max_curvature
    # @return [Grid2D] self
    def refine_recursively(max_curvature) 
      while self.refine(max_curvature) > 0
      end
      self
    end

    # @return [Float] current maximum curvature among all the tiles
    def max_nvariance() 
      max_curvature = 0
      @tiles.each { |i, t| 
        c = t.value.nvariance()
        max_curvature = c if c > max_curvature
      }
      max_curvature
    end

    # Perform evaluation of z-value on each vertex in the grid
    # @return [Grid2D] self
    def compute(computer=nil)
      cmptr = @computer
      cmptr = computer if !computer.nil?
      @vtxs.each { |v|
        val = v.compute(cmptr)
        @min_val = val if val < @min_val
        @max_val = val if val > @max_val
      }
      self
    end

    # Pretty print
    def to_s
      retval = ""
      retval = retval + @vtxs.to_s
      retval
    end

    # @return [String] mesh in the Java3D obj file format
    # @see {http://download.java.net/media/java3d/javadoc/1.4.0/com/sun/j3d/loaders/objectfile/ObjectFile.html}
    def to_java3d_obj
      retval = StringIO.new
      @vtxs.each { |v|      
        val = v.initialized? ? v.value.to_s : "X"
        retval << "v #{v.x} #{v.y} #{val}\n"
      }
      @tiles.each { |i,t|
        retval << "f #{t.value.vtx[0]} #{t.value.vtx[1]} #{t.value.vtx[2]}\n"
      }
      retval.string
    end
  end

  # A tile is a flat triangular surface defined by three vertices.
  # All tiles are stored in the LNode in the linked list LList
  class Tile
    
    # @return [Array] Array of three Vertexes forming this tile
    attr_accessor :vtx

    # @return [TrueClass,FalseClass] parameter to be used 
    # internally indicating if this tile should be inspected for splitting
    attr_accessor :inspect

    @lnode 

    # @param vtx1 vtx2 vtx3 [Vertex] three verixes forming tile.
    # @param grd [Grid2D] gid, which this tile is part of
    def initialize(vtx1,vtx2,vtx3, grd) 
      @vtx=[]
      raise "Invalid vtx1 type" if vtx1.instance_of? Vertex
      raise "Invalid vtx2 type" if vtx2.instance_of? Vertex
      raise "Invalid vtx3 type" if vtx3.instance_of? Vertex
      @vtx[0] = vtx1
      @vtx[1] = vtx2
      @vtx[2] = vtx3

      @grd  = grd
      @nv   = nil

      # regsiter this tile with each vertex that forms it
      @vtx.each { |v| @grd.vtxs[v-1].register_tile(self) }
      
      @inspect=true
      @lnode = nil
    end
    
    # Find all nearby tiles connected to this one through the common edges ( up to three tiles )
    # and for each tile calculate cross product between normal vectors of this tile and nearby ones
    # Return maximum of these three cross products by absolute value. This will be our rough measure 
    # of curvature of surface formed this set of tiles.
    def nvariance(debug=false)
      nv0 = self.normal_vector
      all_near_by_tiles = []
      all_near_by_tiles << ( @grd.vtxs[vtx[0]-1].tiles & @grd.vtxs[vtx[1]-1].tiles )
      all_near_by_tiles << ( @grd.vtxs[vtx[0]-1].tiles & @grd.vtxs[vtx[2]-1].tiles )
      all_near_by_tiles << ( @grd.vtxs[vtx[1]-1].tiles & @grd.vtxs[vtx[2]-1].tiles )
      all_near_by_tiles.flatten!
      all_near_by_tiles.reject! { |t| t == self }.uniq!
      #all_near_by_tiles.each { |t|
      # puts "#{t} #{@grd.vtxs[t.vtx[0]-1]} #{@grd.vtxs[t.vtx[1]-1]} #{@grd.vtxs[t.vtx[2]-1]} #{t.normal_vector}\n"
      # t.form_normal_vector(true)
      #}
      m=all_near_by_tiles.map { |t| t.normal_vector }
      print "#{self}->#{nv0}->#{nv0.abs}\n" if debug
      if debug
        m.each { |nv| print "#{nv0}x#{nv}->#{nv0.cross_product(nv).abs}\n"  }
      end
      m.map { |nv| nv0.cross_product(nv).abs }.max
    end
    
    # Create back reference to LNode in which this tile is a payload.
    def connect(lnode)
      @lnode = lnode
    end

    # Remove from linked list of tiles
    def unlink 
      @lnode.unlink unless @lnode.nil?
    end

    # Two tiles are equal when their vertixes are geometrically equal.
    def ==(tile)
      self.vtx == tile.vtx
    end

    # Form normal vector to this tile if needed and return it.
    def normal_vector
      if !@nv.nil? 
        return @nv
      end
      r1x=@grd.vtxs[vtx[1]-1].x-@grd.vtxs[vtx[0]-1].x
      r1y=@grd.vtxs[vtx[1]-1].y-@grd.vtxs[vtx[0]-1].y
      r1z=@grd.vtxs[vtx[1]-1].value-@grd.vtxs[vtx[0]-1].value
      r2x=@grd.vtxs[vtx[2]-1].x-@grd.vtxs[vtx[0]-1].x
      r2y=@grd.vtxs[vtx[2]-1].y-@grd.vtxs[vtx[0]-1].y
      r2z=@grd.vtxs[vtx[2]-1].value-@grd.vtxs[vtx[0]-1].value

      #if debug
      #  print "n1=[#{r1x},#{r1y},#{r1z}] n2=[#{r2x},#{r2y},#{r2z}]\n"
      #end

      nv = [(r1y*r2z-r1z*r2y), (r1z*r2x-r1x*r2z), (r1x*r2y-r1y*r2x)]
      length = Math::sqrt(nv[0]**2+nv[1]**2+nv[2]**2)
      nvv=nv.map { |e| e/length }
      def nvv.to_s
        "NV:=(#{self[0]}, #{self[1]}, #{self[2]})"
      end
      @nv = nvv
      @nv
    end

    # Has this tile been inspected
    def inspect?
      @inspect
    end

    # Pretty print
    def to_s
      "Tile[#{@vtx[0]},#{@vtx[1]},#{@vtx[2]};#{@inspect?'t':'f'}]"
    end

    # Split new tile and calculate new value for new vertex
    def split_and_evaluate
      self.split(true)
    end

    # If curvature returned by nvariance() is greater then some prescribed value 
    # then this method can be called to split this tile by adding new vertex and 
    # optionally evaluate value at that new vertex
    def split(evaluate=false)
      @inspect = false # no more ispection for this tile

      #print "splitting #{self}]\n"
      l=[0,1,2].map { |m| 
        ((m+1)..2).to_a.map { |n| 
          (@grd.vtxs[@vtx[m]-1].x-@grd.vtxs[@vtx[n]-1].x)**2+(@grd.vtxs[@vtx[m]-1].y-@grd.vtxs[@vtx[n]-1].y)**2
        }
      }.flatten.each_with_index.max[1]

      # introduce new vertex and record existing end points
      vtx1=-1
      vtx2=-1
      vtx3=-1
      vtx4=nil
      case l
      when 0 # longest edge is 0-1
        vtx1=vtx[0]
        vtx2=vtx[1]
        vtx3=vtx[2]
      when 1 # longest edge is 0-2
        vtx1=vtx[0]
        vtx2=vtx[2]
        vtx3=vtx[1]
      when 2 # longest edge is 1-2
        vtx1=vtx[1]
        vtx2=vtx[2]
        vtx3=vtx[0]
      end

      vtx_new = 
        Vertex.new((@grd.vtxs[vtx1-1].x+@grd.vtxs[vtx2-1].x)/2.0, (@grd.vtxs[vtx1-1].y+@grd.vtxs[vtx2-1].y)/2.0, @grd)

      vtx_new.compute() if( evaluate ) 

      @grd.vtxs << vtx_new

      # add two new tiles formed out of self

      t = Tile.new(@grd.vtxs.size,vtx3,vtx1, @grd)
      t.connect(@grd.tiles.append(t))

      t = Tile.new(vtx3,@grd.vtxs.size,vtx2, @grd)
      t.connect(@grd.tiles.append(t))

      # find adjacent tile
      adjacent = (@grd.vtxs[vtx1-1].tiles & @grd.vtxs[vtx2-1].tiles) - [self]
      if !adjacent.nil? and adjacent.size > 0
        adj_tile = adjacent[0]
        vtx4=(adj_tile.vtx - [vtx1, vtx2]).first

        # add two new tiles formed out of adjacent tile
        t = Tile.new(@grd.vtxs.size,vtx1,vtx4, @grd)
        t.connect(@grd.tiles.append(t))

        t = Tile.new(vtx4,vtx2,@grd.vtxs.size, @grd)
        t.connect(@grd.tiles.append(t))
        
        # unlink ajd_tile from the list
        adj_tile.unlink
        #print "unlinking adj #{adj_tile}\n"
        adj_tile.inspect = false
        @grd.vtxs[vtx1-1].remove_tile adj_tile
        @grd.vtxs[vtx2-1].remove_tile adj_tile
        @grd.vtxs[vtx4-1].remove_tile adj_tile
      end
      
      self.unlink
      
      @grd.vtxs[vtx1-1].remove_tile self
      @grd.vtxs[vtx2-1].remove_tile self
      @grd.vtxs[vtx3-1].remove_tile self
    end
  end

  # This class represents point in the grid. In the normal course of events you do not have 
  # explicitly create instances of this class.
  class Vertex 

    attr_accessor :x, :y, :value, :initialized, :tiles
    
    # @param x [Float] x coordinate of the Vertex
    # @param y [Float] x coordinate of the Vertex
    # @param grd [Grid2D] reference to a grid object
    def initialize(x, y, grd)
      @x = x
      @y = y
      @initialized = false
      @value = 0
      @grd = grd

      @tiles = []
    end

    # If value has never been computed then such vertex considered to be 
    # not initialized. This method allows to query for such condition.
    def initialized?
      initialized
    end

    # A Vertex can participate in several tiles.
    # This method allows to register a particular tile as connected to this Vertex.
    def register_tile(tile)
      @tiles << tile
      self
    end

    # Remove tile connected to this vertex. Such operation is done when 
    # mesh refinement is performed, which results in new vertexes introduced 
    # and tiles split into several new tiles.
    def remove_tile(tile)
      @tiles.reject! { |t| t == tile }
      self
    end

    # Given a registered in the grid computer function, compute z value for this node.
    # This changes 'initialized' state to true
    #
    # @return [Float] computed value
    def compute(computer=nil)
      cmptr=@grd.computer
      cmptr = computer if !computer.nil?
      @value = cmptr.call(x, y)
      @initialized = true
      @value
    end

    # Pretty print
    def to_s
      "Vtx[#{@x},#{@y};#{@value},#{@initialized}]"
    end
  end

end
