using CSV, DataFrames

function find_candidates(bus::DataFrame, branch::DataFrame)
    # Extract bus indices
    bus_indices = bus.idx

    # Get all possible branches (all pairs of bus indices, ordered)
    all_possible_branches = unique([(i, j) for i in bus_indices for j in bus_indices if i != j])
    possible_branches_df = DataFrame(
        start_idx = [x[1] for x in all_possible_branches],
        end_idx = [x[2] for x in all_possible_branches]
    )
    candidates = anti_join(possible_branches_df, branch, on = [:start_idx, :end_idx])
    
    # Add branch_id 
    max_branch_id = maximum(branch.branch_id)
    candidates.branch_id = max_branch_id .+ (1:size(candidates, 1))

    return candidates
end
