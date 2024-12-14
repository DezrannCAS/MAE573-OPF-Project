using JuMP
using Gurobi

function optimize_network(
    data::Dict, 
    scenarios::Vector{Dict}, 
    probabilities::Vector{Float64}, 
    max_modifications::Int
)
    # Define sets based on data
    B = 1:length(data["branch"])           # Set of original branches
    L = 1:5                                # Set of available links (candidate connections), adjust as needed
    S = 1:length(scenarios)                # Set of scenarios

    # Extract branch parameters
    x_i = [data["branch"][i]["x"] for i in B]       # Reactance of original branches
    r_i = [data["branch"][i]["ratea"] for i in B]   # Capacity of original branches

    # Define the JuMP model
    model = Model(Gurobi.Optimizer)

    # Decision variables
    @variable(model, z[i in B], Bin)       # Binary variable for branch removal
    @variable(model, y[j in L], Bin)       # Binary variable for link creation
    @variable(model, x[j in L] >= 0)       # Reactance for a new link
    @variable(model, r[j in L] >= 0)       # Capacity for a new link

    # Cost function based on the DCOPF
    function cost_function(z, y, x, r, scenario)
        # Replace with actual DCOPF-based cost computation
        return sum(z) + sum(y) + sum(x) + sum(r)  # Placeholder computation
    end

    # Objective: Minimize the expected cost over all scenarios
    @expression(model, expected_cost, 
        sum(probabilities[s] * cost_function(z, y, x, r, scenarios[s]) for s in S)
    )
    @objective(model, Min, expected_cost)

    # Constraints
    # 1. Link removal and creation balance
    @constraint(model, sum(z[i] for i in B) == sum(y[j] for j in L))

    # 2. Limit on link modifications
    @constraint(model, sum(y[j] for j in L) <= max_modifications)

    # 3. Attribute conservation
    @constraint(model, 
        sum((1 - z[i]) * x_i[i] for i in B) + sum(y[j] * x[j] for j in L) == sum(x_i)
    )
    @constraint(model, 
        sum((1 - z[i]) * r_i[i] for i in B) + sum(y[j] * r[j] for j in L) == sum(r_i)
    )

    # 4. Domain constraints
    @constraint(model, [j in L], x[j] <= 1000 * y[j])  # Enforcing x_j = 0 when y_j = 0
    @constraint(model, [j in L], r[j] <= 1000 * y[j])  # Enforcing r_j = 0 when y_j = 0

    # Solve the model
    optimize!(model)

    # Output results
    if termination_status(model) == MOI.OPTIMAL
        return Dict(
            "z" => value.(z), 
            "y" => value.(y), 
            "x" => value.(x), 
            "r" => value.(r), 
            "expected_cost" => objective_value(model)
        )
    else
        error("No optimal solution found.")
    end
end

# Now we need to turn this z, y, x, r into actual data that can be fed to DCOPF solver, and tested later

