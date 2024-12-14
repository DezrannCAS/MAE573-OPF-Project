# Load modules
include("simulation.jl")
include("optimization.jl")
include("utils.jl")

using .Utils
using .Optimization
using .Simulation

# Load data 
data_dir = "/home/esteban_nb/dirhw/mae573-term-project/data"
data = Utils.load_data(data_dir)


# Simple DCOPF
# println("Building simple DCOPF...\n")
# model = Optimization.build_dcopf(data)
# println("Solving simple DCOPF...\n")
# results = Optimization.solve_model(model, data)
# print(results)

# Stochastic DCOPF

num_scenarios = 50
scenarios = generate_scenarios(data, num_scenarios, 0.1, 0.1)
probabilities = fill(1/num_scenarios, num_scenarios)

println("Performing stochastic DCOPF...\n")
model = Optimization.perform_stochastic_dcopf(data, scenarios, probabilities)
