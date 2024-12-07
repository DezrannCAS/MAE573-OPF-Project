# Load modules
include("simulation.jl")
include("optimization.jl")
include("utils.jl")

using .Utils
using .Optimization

# Load data 
data_dir = "/home/esteban_nb/dirhw/mae573-term-project/data"
data = Utils.load_data(data_dir)


# Simple DCOPF
println("Executing simple DCOPF...")
model = Optimization.build_dcopf(data)
results = Optimization.solve_model(model, data)
print(results)

