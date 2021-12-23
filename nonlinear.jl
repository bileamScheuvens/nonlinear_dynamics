using GLMakie
using Colors

"""
step function used in lift to compute position based on previous node and time step
"""
function step(point)
    # unpack coords
    x,y = to_value(point)
    # reference to timestep for readability
    t = tnode[]
    
    # expression to evaluate 
    #( -t^2-x*y+1, -x*y, +x*t + y + t )
    ( x^2 - x*t + y + t, x^2 + y^2 + t^2 - x*t -x + y)
end

"""
create num_points observables according to step function
"""
function init_nodes(num_points)
    # create node for timestep with value of first frame
    tnode = Node(frames[1])
    # create source node at ( t, t )
    last_point = lift(x-> Point2f0(x,x), tnode)

    # init point list and colors
    points = []
    cmap = distinguishable_colors(num_points)
    
    # add num_point nodes, linked via lift
    for _ in 1:num_points
        push!(points, last_point)
        last_point = lift(step, last_point)
    end
    # return tnode, points and cmap
    tnode, points, cmap
end

"""
initialize empty scene with specified zoom
"""
function init_scene(zoom)
    # create empty themed scatterplot
    set_theme!(theme_black())
    fig, ax = scatter([0],[0], color="black", markersize=1)
    # hide axes and tick labels
    hidedecorations!(ax)

    # set zoom
    limits!(ax, -zoom, zoom, -zoom, zoom)
    # return fig and ax
    fig, ax
end

"""
add scatter trace for each node
"""
function add_nodes(points, cmap, size)
    # for each node
    for (pos, point) in enumerate(points)
        # create scatter plot with corresponding color
        scatter!(point, color=cmap[pos], 
                markersize=size
                )
    end
end

# PARAMETERS - mostly trial and error
num_points = 1000
zoom = 0.4
frames = -0.1:0.0006:0.15
framerate = 60
size = 3
# video length in seconds
length(frames) / framerate



tnode, points, cmap = init_nodes(num_points)
fig, ax = init_scene(zoom)
add_nodes(points, cmap, size)

record(fig, "spiral_1000_3.mp4", vcat(frames,reverse(frames));
        framerate = framerate) do frame
            tnode[] = frame
end
