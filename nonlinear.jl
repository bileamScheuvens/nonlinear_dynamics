using GLMakie
using Colors
using Statistics
using DataStructures: CircularBuffer

# extend domain of trig functions to inf and nan
sinp(x) = x in (-Inf, Inf, NaN) ? 0 : sin(x)
cosp(x) = x in (-Inf, Inf, NaN) ? 0 : cos(x)
tanp(x) = x in (-Inf, Inf, NaN) ? 0 : tan(x)


"""
generate expression either from string representation or randomly based on preset building blocks

# Arguments
- `repr::String=""`: uppercase string representation of equation
- `num_blocks::Int=4`: number of blocks used to construct expression, only relevant if repr=""
"""
function gen_expression(; num_blocks::Int=4, repr::String="")
    funcs = [
        (t,x,y) -> +x,       # A 1
        (t,x,y) -> +y,       # B 2
        (t,x,y) -> +x*t,     # C 3
        (t,x,y) -> +x*y,     # D 4
        (t,x,y) -> +y*x*t,   # E 5
        (t,x,y) -> +t^2,     # F 6
        (t,x,y) -> +x^2,     # G 7
        (t,x,y) -> +y^2,     # H 8
        (t,x,y) -> +sinp(x), # I 9
        (t,x,y) -> +sinp(y), # J 10
        (t,x,y) -> +cosp(x), # K 11 
        (t,x,y) -> +cosp(y), # L 12
        (t,x,y) -> +cosp(t), # M 13
        (t,x,y) -> -x,       # N 14 
        (t,x,y) -> -y,       # O 15
        (t,x,y) -> -x*t,     # P 16
        (t,x,y) -> -x*y,     # Q 17 
        (t,x,y) -> -y*x*t,   # R 18
        (t,x,y) -> -t^2,     # S 19
        (t,x,y) -> -x^2,     # T 20
        (t,x,y) -> -y^2,     # U 21
        (t,x,y) -> -sinp(x), # V 22 
        (t,x,y) -> -sinp(y), # W 23
        (t,x,y) -> -cosp(x), # X 24
        (t,x,y) -> -cosp(y), # Y 25
        (t,x,y) -> -cosp(t)  # Z 26
    ]
    repr = repr != "" ? repr : string(Char.(rand(1:length(funcs), num_blocks) .+ 64)...)
    term(t,x,y) = sum(funcs[Int(c)-64](t,x,y) for c in repr)
    term, repr
end

"""
compute new coordinates according to given equation
"""
function comp_coord(t,x,y)
    # expression to evaluate 
    #( -t^2-x*y+1, -x*y, +x*t + y + t )
    #( x^2 - x*t + y + t, x^2 + y^2 + t^2 - x*t -x + y)
    (xexpr(t,x,y), yexpr(t,x,y))
end


"""
wrapper around comp_coord used in lift to compute position based on previous node and time step
"""
function step(point)
    # pass unpacked coords and timestep to comp_coord
    x,y = to_value(point)
    comp_coord(tnode[],x,y)
end


"""
heuristic to compute reasonable zoom such that q share of points on average are visible
"""
function estimate_zoom(frames, num_points; q=0.5)
    xs = Vector{Float64}([])
    ys = Vector{Float64}([])
    # sample every tenth frame
    for t in frames[1]:Int(round(length(frames)/10)):frames[end]
        # start at point (t,t)
        (last_x, last_y) = comp_coord(t,t,t)
        for _ in 1:num_points
            push!(xs, last_x)
            push!(ys, last_y)
            (last_x, last_y) = comp_coord(t,last_x,last_y)
        end
    end
    filter!(!isnan, xs)
    filter!(!isnan, ys)
    filter!(!isinf, xs)
    filter!(!isinf, ys)
    xzoom = quantile(abs.(xs), q)
    yzoom = quantile(abs.(xs), q)
    # add 10%
    (xzoom*1.1, yzoom*1.1)
end



"""
create num_points observables according to step function
"""
function init_nodes(num_points)
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
    # return points and cmap
    points, cmap
end

"""
initialize empty scene with specified zoom
"""
function init_scene((xzoom, yzoom))
    # create empty themed scatterplot
    set_theme!(theme_black())
    fig, ax = scatter([0],[0], color="black", markersize=1)
    # hide axes and tick labels
    hidedecorations!(ax)

    # set zoom
    limits!(ax, -xzoom, xzoom, -yzoom, yzoom)
    println(" ---- \nxzoom set to $(xzoom) \nyzoom set to $(yzoom)\n ---- ")
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

"""
add line trace for each tail
"""
function add_tails(tails, cmap, size)
    # for each node
    for (pos, tail) in enumerate(tails)
        # create scatter plot with corresponding color
        lines!(tail, color=(cmap[pos],0.2), 
                markersize=size/2
                )
    end
end

observe(ncirc) = map(x->tuple(x...), vcat(ncirc))

function run(;num_points = 500, frames = -0.5:0.005:0.5, framerate = 20,size = 4, 
            showtail=false, taillength=5, rep=("",""), q=0.4, filename="random")

    global xexpr, xrep = gen_expression(num_blocks=4, repr=rep[1])
    global yexpr, yrep = gen_expression(num_blocks=4, repr=rep[2])

    println("length in seconds: " * string(length(frames) / framerate))
    println("x: $(xrep), y: $(yrep)")
    zoom = estimate_zoom(frames, num_points; q=q)
    # create node for timestep with value of first frame
    global tnode = Node(frames[1])

    fig, ax = init_scene(zoom)

    points, cmap = init_nodes(num_points)

    add_nodes(points, cmap, size)

    if showtail
        # initialize buffers
        tailpos = [CircularBuffer(taillength) for _ in 1:num_points]
        # fill first value with 0 as empty buffer throws error
        [push!(buf, Point2f0(0,0)) for buf in tailpos]
        # init nodes
        tailnodes = [Node(tail) for tail in tailpos]
        # create dependencies
        tails = [lift(observe, tail) for tail in tailnodes]
        add_tails(tails, cmap, size)
        #[popfirst!(buf) for buf in tailpos]
    end
    
    
    record(fig, "recordings/$(filename).mp4", frames; #vcat(frames,reverse(frames));
            framerate = framerate) do frame
                tnode[] = frame
                if showtail
                    for (pos, point) in enumerate(points)
                        push!(tailpos[pos], point[])
                    end
                    for (pos, tailnode) in enumerate(tailnodes)
                        tailnode[] = tailpos[pos]
                    end
                end
                sleep(1/framerate)
                ax.title = "x: $(xrep), y: $(yrep)\nzoom: $(round.(zoom, digits=3))\n" * string(tnode[])
    end
end

run(frames=-0.5:0.02:0.5, rep=("",""), q=0.4, filename="random", num_points=200, showtail=true)

"""
Notable codes:
Cool spiral: "GPB, GHFPNB"
beam: "IHDJ", "SVVE"
triangle explosion: "NFWY", "HTRB"
???: "FWEZ", "QABF"
"""