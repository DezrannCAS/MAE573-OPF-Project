# TODO: 
# - fix types, docs and other TODOs
# - write the evaluate function

module Simulation

export generate_batches, generate_scenarios, evaluate


"""
Generate scenarios, with variability on demand (between 0 and 1) and probability of link failure
"""
function generate_scenarios(data::Dict, num_scenarios::Int, variability::Float64, prob_failure::Float64)
    scenarios = []
    for _ in 1:num_scenarios
        scenario_data = deepcopy(data)

        # Randomly vary demand
        for row in eachrow(scenario_data[:load])
            row[:demand] *= 1.0 + variability * (rand() - 0.5)
        end

        # Randomly disable links
        if rand() < prob_failure
            link_id = rand(1:nrow(scenario_data[:branch]))
            scenario_data[:branch][link_id, :flow] = 0.0  # TODO: fix this -> increase conductance instead
        end

        push!(scenarios, scenario_data)
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