using PDMP, Base.Test

srand(1777)
n = 1000           # n observations
p = 5              # n dimensions (covariates)
X = randn(n,p)+0.1  # feature matrix
w = 5*rand(p)       # true vector of parameters
# observations according to a logistic thresholded to {-1,1}
y = (PDMP.logistic.(X*w) .> rand(n)) .* 2.0 .- 1.0
# proxy for N*L upper bound
b = sum( mapslices(_->norm(_)^2,X,1) )/4

# DATA MODEL
dm = PDMP.LogReg(X,y,b)

# GEOMETRY
ns, a             = eye(p), zeros(p)
geom              = PDMP.Polygonal(ns,a)
nextboundary(x,v) = PDMP.nextboundary(geom, x, v)

# GRADIENTS and IPPSampling
gll_cv          = PDMP.gradloglik_cv(dm, w)
gllstar         = PDMP.gradloglik(dm, w)
lb              = PDMP.LinearBound(w, gllstar, dm.b)
nextevent(x, v) = PDMP.nextevent_bps(lb, x, v)

# SIMULATION
T           = Inf          # simulation 'time'
maxgradeval = 500000       # max number of gradient evaluations
lref        = 2.           # refreshment rate
x0          = w            # initial point for the trajectory
v0          = randn(dm.p)  # draw velocity from normal distr
v0         /= norm(v0)     # normalise velocity

sim = PDMP.Simulation(
        x0, v0, T, nextevent, gll_cv, nextboundary, lref;
        maxgradeval = maxgradeval);

# all the basic ones

xrand = randn(p)
vrand = randn(p)

@test   sim.x0 == x0 &&
        sim.v0 == v0 &&
        sim.T  == T  &&
        (srand(12);sim.nextevent(xrand, vrand).tau)==
        (srand(12);nextevent(xrand, vrand).tau)
@test   (srand(12);sim.gll(xrand))==(srand(12);gll_cv(xrand)) &&
        sim.nextboundary(xrand, vrand) == nextboundary(xrand, vrand) &&
        sim.lambdaref == lref &&
        sim.algname == "BPS"
@test   sim.dim == length(x0) &&
        sim.mass == eye(0) &&
        sim.blocksize == 1000 &&
        sim.maxsimtime == 4e3 &&
        sim.maxsegments == Int(1e6) &&
        sim.maxgradeval == maxgradeval

simf = PDMP.Simulation(
        x0, v0, T, nextevent, gll_cv, nextboundary, lref, "bps";
        maxgradeval = maxgradeval);

@test simf.algname == "BPS"

@test_throws AssertionError PDMP.Simulation(
        x0, v0, T, nextevent, gll_cv, nextboundary, lref, "bpsasdf";
        maxgradeval = maxgradeval);
