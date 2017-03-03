module TLLR

using Convex
using ECOS

import Base.size
export fit, predict

"""
  indextobeta(b::Integer, K::Integer)::Array{Int64,1}

  returns 2 * bin(b,K) - 1

  where bin(b,K) is a vector of K elements containing the binary
  representation of b.
"""
function indextobeta(b::Integer, K::Integer)
  result::Array{Int64,1} = []
  for k = 1:K
    push!(result, 2(b % 2)-1)
    b >>= 1
  end

  result
end

"""
    fit(X::Array{Float64,2}, y::Array{Float64,1}, P::Array{Int,2}; beta=randomvalues)

Fits a TLLRegression model to the given data and resturns the
learnt model (see the Result section).

# Arguments

* `X`: \$N × M\$ matrix describing the examples
* `y`: \$N\$ vector with the output values for each example
* `P`: \$M × K\$ matrix specifying how to partition the \$M\$ attributes into
    \$K\$ subsets. \$P_{m,k}\$ should be 1 if attribute number \$m\$ belongs to
    partition \$k\$.
* `verbose`: if true (or 1) the output of solver will be shown
* `η`: regularization factor, higher values implies more regularized solutions

# Result

A tuple of the form: `(opt, a, b, t, P)`

* `opt`: optimal value of the objective function (loss + regularization)
* `a`: values of the α variables at the optimal point
* `b`: values of the β variables at the optimial point
* `t`: the intercept at the optimal point
* `P`: the partition matrix (copied from the input)

The output model predicts points using the formula: f(X) = \$X * (P .* a) * b + t\$.

"""
function fit(X::Array{Float64,2}, y::Array{Float64,1}, P::Array{Int,2}; verbose=0, η=1)
  # row normalization
  M,K = size(P)

  results = []

  for b in 0:(2^K-1)
    α = Variable(M, Positive())
    t = Variable()
    β = indextobeta(b,K)

    loss = norm(X * (P .* (α * ones(1,K))) * β + t - y)^2
    regularization = η * norm(α,2)
    p = minimize(loss + regularization)
    Convex.solve!(p, ECOSSolver(verbose=verbose))

    info("iteration $b optval: $(p.optval)")
    push!(results,(p.optval, α.value, β, t.value, P))
  end

  optindex = indmin((z -> z[1]).(results))
  opt,a,b,t,_ = results[optindex]


  A = sum(P .* a, 1)
  a = sum((P .* a) ./ A, 2)
  b = b .* A'

  (opt, a, b, t, P)
end


"""
  predict(model::Tuple, X::Array{Float64,2})

  returns the predictions of the given model on examples in X

  #see

    fit(X::Array{Float64,2}, y::Array{Float64,1}, P::Array{Int,2}; beta=randomvalues)
"""
function predict(model, X::Array{Float64,2})
  (_, α, β, t, P) = model
  X * (P .* α) * β + t
end

end
