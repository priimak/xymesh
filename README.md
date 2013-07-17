Adaptive mesh refinement for XY->Z problems
=========================================

Overview
--------

When performing numerical simulations one often deals with need to calculate certain
values for each point in the predefined grid on XY plane, which typically looks like 
this 
<br/><center><img src="images/basic_grid.gif"/></center><br/>
As a result of such
calculation a 2D surface is formed in the X-Y-Z space. For example, the X axis might
correspond to applied voltage and Y axis to temperature and calculated value might be
current. More often than not, such surface have large smooth regions and small regions
where it is bending precipitously ( has high curvature ). If a simple rectilinear
grid of X and Y parameters is used to drive calculations then to capture features of
regions with high curvature one has to use, often, very fine mesh. Here is an example of
calculating for the following function
```ruby
Math::cos(x**2+y**2)/(x**2+y**2+0.5)
```
For the simple rectangular mesh, for X and Y changing from -2 to 2 and 121 vertexes 
in total
<br/>
<center>
<img src="images/rough_surface.gif"/>
</center>
<br/>
That is very rough, however there are just a couple of regions where we need the fine 
mesh. Here is an example of how it looks with the fine mesh.
<br/><center><img src="images/fine_surface.gif"/></center><br/>
This however required 10,000 vertexes.
But what is really needed here is to tip-toe over regions that are strongly bending and 
make just a few computations in the smooth regions. Additionally we want such procedure 
to be fully automated. So that we can start with very rough grid and let separate program
add new points to the grid as necessary to make it as smooth as some predefined value.
And this is exactly what this ruby package does. Here is what it can archive starting 
from 10 by 10 grid.
<br/><center><img src="images/refined_surface.gif"/></center><br/>
This is pretty smooth. And here is the grid with vertexes.
<br/><center><img src="images/refined_surface_and_grid.gif"/></center><br/>
You can see that vertexes cluster right they need to be to expose essential features 
of the surface and most importantly it required only 1481 vertexes. 

Here is an example of an actual simulation. 
<br/><center><img src="images/simulation_surface_and_grid.gif"/></center><br/>
Again, you can see here that vertexes cluster in the areas that contain essential 
features where curvature is the greatest. 
Following X-Y view show projections of generated grid and its zoom
<br/><center><img src="images/simulation_grid_xy.gif"/></center><br/>
<br/><center><img src="images/simulation_grid_xy_detail.gif"/></center><br/>

Algorithm
---------

To accomplish goals described in the overview following algorithm has been devised.
First, rectangular grid of vertexes is created spanning from **Xmin** to **Xmax** 
and from **Ymin** to **Ymax** with steps **dx=(Xmax - Xmin)/Nx** 
and **dy=(Ymax - Ymin)/Ny**, where **Nx** and **Ny** are number of steps along 
each axis. Then a set of triangular tiles is created.
<br/><center><img src="images/basic_grid_with_indexes.gif"/></center><br/>
All of the vertexes are arranged into array **V** and tiles in the doubly linked 
list **T**. Note that both, tiles and vertexes are numbered from 1, not 0.
Each of the vertexes are considered to be uninitialized until Z value 
(elevation above X-Y plane) is computed. Once Z values are computed we can proceed to 
mesh refinement based on some measure of curvature. The measure of curvature that we 
are using here significantly differs from classical definition and so as not to confuse 
two we use term "**nvariance**" and it is defined as following. 
<br/><center><img src="images/basic_grid_with_normals.gif"/></center><br/>
For each of the tiles
we compute normal vector (shown in blue in the picture above) and for each adjacent 
tile ( sharing common edge ) we take a cross product of their normal vectors, 
absolute value of which we call nvariance or **NV**.
Thus nvariance can be calculated for any two pairs of tiles **i** and **j**, i.e. 
**NV=f(i,j)**. For us only nvariance of adjacent tiles has meaning of rough 
approximation of curvature. Obviously normal vectors of being length 1, nvariance changes 
from 0, for tiles that lie in the same plane, to 1, for tiles that lie at the 90 degree 
angle. And since we assume simple mapping of points in X-Y plane to only one point along Z 
axes, we will not ever have two tiles at the angle greater than 90 degrees.
If the nvariance of two given tiles is greater then we split in two that tile which has 
largest perimeter. Which ever tile we decide to split, we do so by adding new vertex along 
the longest side of that tile. For example for the picture above we might have found that 
nvariance of tiles 2 and 3 is larger than out preset limit and since perimeter of tile 3 is 
greater that will be the tile to split, like so.
<br/><center><img src="images/split1_grid_with_normals.gif"/></center><br/>
Note that tile 3 is split away from the tile 2, with which it has the highest nvariance.
Also, note that tile 4 also became split, which we have to do just to maintain surface 
triangulation. If on a next iteration it was found that tiles 2 and 3 are still at the 
higher nvariance than desired, then tile 2 will be split, since its the one among two that 
has greater perimeter. As the iterative process continues it is possible that two tiles 
will be split along the common edge of tiles 2 and 3. By always splitting to the longest 
edge of larger, by perimeter, of two tiles, we avoid pathological case when very thing, with 
small surface area and large perimeter, tiles are created. This process could continue 
indefinitely until no two adjustment tiles have nvariance greater than desired. However, 
if there is some noise in the Z value, for example due to numerical errors in simulation,
then once the tile size reaches size comparable with size of these noise ripples our 
recursive process may restart and continue indefinitely. We need to limit either number 
of vertexes or area of the tiles. In this algorithm we limit not the area of the tile, 
but the area of its projection to X-Y plane in percentage, from 0 to 1, of the area of 
the original unrefined tiles. This guaranties that this refinement process stops. In 
pseudo-code this process looks like this

    Vertexes,Tiles = initialize_mesh(Xmin,Xmax,Nx, Ymin,Ymax,Ny)
    
    foreach vertex in Vertexes
        vertex.z = compute(vertex.x, vertex.y)

    do 
        tiles_split = 0
        foreach tile in Tiles
            if largest_nvariance(tile) > max_nvariance
                nv_tile = tile_with_which_this_tile_tile_has_largest_nvariance(tile) 
                if perimeter_of(tile) > perimeter_of(nv_tile) 
                    mark_for_splitting(tile)
                else
                    mark_for_splitting(nv_tile)

        foreach tile in maked_for_splitting(Tiles)
            if area_in_XY_plane(tile) > min_tile_area
                split_and_compute_at_new_vertex(tile)
                tiles_split = tiles_split + 1
    while tiles_split > 0

Installation
------------

    $ gem build xymesh.gemspec
    $ sudo gem install ./xymesh-0.1.0.gem

Usage
-----

TO BE WRITTEN
