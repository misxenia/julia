# This file is a part of Julia. License is MIT: http://julialang.org/license

## Matrix factorizations and decompositions

abstract Factorization{T}

eltype{T}(::Type{Factorization{T}}) = T
transpose(F::Factorization) = error("transpose not implemented for $(typeof(F))")
ctranspose(F::Factorization) = error("ctranspose not implemented for $(typeof(F))")

macro assertposdef(A, info)
   :(($info)==0 ? $A : throw(PosDefException($info)))
end

macro assertnonsingular(A, info)
   :(($info)==0 ? $A : throw(SingularException($info)))
end


### General promotion rules
convert{T}(::Type{Factorization{T}}, F::Factorization{T}) = F
inv{T}(F::Factorization{T}) = A_ldiv_B!(F, eye(T, size(F,1)))

# With a real lhs and complex rhs with the same precision, we can reinterpret
# the complex rhs as a real rhs with twice the number of columns
function (\){T<:BlasReal}(F::Factorization{T}, B::VecOrMat{Complex{T}})
    c2r = reshape(transpose(reinterpret(T, B, (2, length(B)))), size(B, 1), 2*size(B, 2))
    x = A_ldiv_B!(F, c2r)
    return reinterpret(Complex{T}, transpose(reshape(x, div(length(x), 2), 2)), _ret_size(F, B))
end

for (f1, f2) in ((:\, :A_ldiv_B!),
                 (:Ac_ldiv_B, :Ac_ldiv_B!),
                 (:At_ldiv_B, :At_ldiv_B!))
    @eval begin
        function $f1(F::Factorization, B::AbstractVecOrMat)
            TFB = typeof(one(eltype(F)) / one(eltype(B)))
            BB = similar(B, TFB, size(B))
            copy!(BB, B)
            $f2(convert(Factorization{TFB}, F), BB)
        end
    end
end

# support the same 3-arg idiom as in our other in-place A_*_B functions:
for f in (:A_ldiv_B!, :Ac_ldiv_B!, :At_ldiv_B!)
    @eval $f(Y::AbstractVecOrMat, A::Factorization, B::AbstractVecOrMat) =
        $f(A, copy!(Y, B))
end

"""
    A_ldiv_B!([Y,] A, B) -> Y

Compute `A \ B` in-place and store the result in `Y`, returning the result.
If only two arguments are passed, then `A_ldiv_B!(A, B)` overwrites `B` with
the result.

The argument `A` should *not* be a matrix.  Rather, instead of matrices it should be a
factorization object (e.g. produced by [`factorize`](:func:`factorize`) or [`cholfact`](:func:`cholfact`)).
The reason for this is that factorization itself is both expensive and typically allocates memory
(although it can also be done in-place via, e.g., [`lufact!`](:func:`lufact!`)),
and performance-critical situations requiring `A_ldiv_B!` usually also require fine-grained
control over the factorization of `A`.
"""
A_ldiv_B!

"""
    Ac_ldiv_B!([Y,] A, B) -> Y

Similar to [`A_ldiv_B!`](:func:`A_ldiv_B!`), but return ``Aᴴ`` \\ ``B``,
computing the result in-place in `Y` (or overwriting `B` if `Y` is not supplied).
"""
Ac_ldiv_B!

"""
    At_ldiv_B!([Y,] A, B) -> Y

Similar to [`A_ldiv_B!`](:func:`A_ldiv_B!`), but return ``Aᵀ`` \\ ``B``,
computing the result in-place in `Y` (or overwriting `B` if `Y` is not supplied).
"""
At_ldiv_B!
