# TODO: 
# - fix types, docs and other TODOs
# - write the evaluate function

module Simulation

export generate_batches, generate_scenarios, evaluate

using Random, DataFrames


"""
    generate_scenarios(data::Dict, num_scenarios::Int, demand_variability::Float64, line_failure_prob::Float64)

Generates a set of scenarios with variability in demand and potential line failures.

# Arguments
- `data::Dict`: The original system data containing bus, branch, plant, load, etc.
- `num_scenarios::Int`: Number of scenarios to generate.
- `demand_variability::Float64`: Fractional variability in demand (e.g., 0.1 for ±10% variability).
- `line_failure_prob::Float64`: Probability of a transmission line failure.

# Returns
A vector of scenario dictionaries, where each dictionary contains modified `load` and `branch` data.
"""
function generate_scenarios(data::Dict, num_scenarios::Int, demand_variability::Float64, line_failure_prob::Float64)
    # Unpack original data
    bus = data["bus"]
    branch = data["branch"]
    load = data["load"]

    # Precompute static data
    num_lines = size(branch, 1)
    num_time_steps = size(load, 1)

    scenarios = Vector{Dict}(undef, num_scenarios)

    for s in 1:num_scenarios
        scenario_data = deepcopy(data)

        # Add variability to demand
        modified_load = deepcopy(load)
        for t in 1:num_time_steps
            for col in 3:ncol(load)  # columns 3:end are loads at different demand nodes
                demand_value = load[t, col]
                variability = demand_variability * demand_value
                modified_load[t, col] = demand_value + rand(-variability:0.01:variability)
            end
        end
        scenario_data["load"] = modified_load

        # Simulate line failures
        modified_branch = deepcopy(branch)
        for l in 1:num_lines
            if rand() < line_failure_prob
                modified_branch[l, :x] = 1e6  # Set x to a very high value to simulate failure
            end
        end
        scenario_data["branch"] = modified_branch

        # Store the scenario
        scenarios[s] = scenario_data
    end

    return scenarios
end


"""
Generate batches of scenarios, for different variability on demand and probability of link failure
"""
function generate_batches(data, var_values, fail_values, num_scenario_per_coord)
    batches = Dict{Tuple{Float64, Float64}, Any}()
    for variability in var_values
        for prob_failure in fail_values
            scenario_data = generate_scenarios(data, num_scenario_per_coord, variability, prob_failure)
            batches[(variability, prob_failure)] = scenario_data
        end
    end
    return batches
end


"""
Calculate metrics like redundancy, load energy unserved, etc.
"""
function evaluate(test_data, model_constructor)

    throw(NotImplementedError("evaluate is not yet implemented."))
    
    println("Evaluating the power grid...")
    
    results = Vector{Any}()
    for data in test_data
        model = model_constructor(data)
        output = solve_model(model)
        push!(results, output)
    end
end

end