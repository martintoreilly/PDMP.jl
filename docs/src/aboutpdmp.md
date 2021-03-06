# About PDMP samplers

This page aims at giving a very brief introduction to the concept of PDMP samplers (below we will refer to *the algorithm* but it should be understood as a class of algorithms). We also give some insight into how it is implemented although we cover the implementation in more details in the technical documentation. This is not meant to be a rigorous presentation of the algorithm (for this, please see the references at the bottom of this page). Rather, we focus here on the "large building blocks" behind the algorithm.

## Basic idea (global samplers)

The purpose of the algorithm is to be able to evaluate expected values with respect to an arbitrary target distribution which we assume admits a probability density function  $\pi$. For simplicity, we assume that $\pi:C\to \mathbb R^+$ with $C\subseteq \mathbb R^p$, convex. The objective is therefore to compute a weighted integral of the form:

\begin{equation}
    \mathbb E_{\pi}[\varphi(X)] = \int_{C} \varphi(x)\pi(x)\,\mathrm{d}x
\end{equation}

For some reasonable test-function $\varphi:C\to\mathbb R$. The samples generated by this algorithm constitute a *piecewise-linear path*

\begin{equation}
    x(t) = x^{(i)} + v^{(i)}(t-t_i) \quad \text{for}\quad t\in[t_i, t_{i+1}]
\end{equation}

determined by an initial position $x^{(0)}$ and velocity $v^{(0)}$ at time $t_0=0$ and a set of positive *event times* $t_1,t_2,\dots$. Under some conditions for the generation of the times and the velocities, the expected value can then be approximated with

\begin{eqnarray}
    \mathbb E_{\pi}[\varphi(X)] &\approx& {1\over T} \int_0^T\varphi(x(t))\mathrm{d}t
\end{eqnarray}

and the integral in the right hand side can be expressed as a sum of one-dimensional integrals along each linear segment of the path.

### Generating times and velocities

The algorithm generates a sequence of *triples* of the form $(t_i, x^{(i)}, v^{(i)})$.
Let us assume that the algorithm is currently at one of those event points and show how to compute the next triple. To do so, the algorithm executes the following steps:

1. it generates a travel time $\tau$ drawing from a specific random process,
2. the next position is then obtained by traveling along the current *ray* for the travel time $\tau$ i.e.: $x^{(i+1)} = x^{(i)} + \tau v^{(i)}$,
3. a new velocity $v^{(i+1)}$ is generated.

First, we will explore how the travel time is generated and then, how the new velocity is computed.

#### Sampling a travel time

The effective travel time $\tau$ is obtained as the minimum of three times which we will denote by $\tau_b, \tau_h, \tau_r$. Following the case, the computation of the new velocity will be different.

The first (and most important) one, $\tau_b$, is the first arrival time of an *Inhomogenous Poisson Process* (IPP) with an intensity that should verify some properties with respect to the target distribution. The *Bouncy Particle Sampler* (BPS) in particular considers the following intensity with $U$ the negative log-likelihood of the (possibly unnormalised) target $\pi$:

\begin{eqnarray}
    \lambda(\tau; x, v) = \langle \nabla U(x + \tau v ), v \rangle^+
\end{eqnarray}

where $x$ and $v$ are the current points and $f^+=\max(f,0)$. Sampling from an IPP is not trivial in general but there are a few well known techniques that can be applied depending on the target (see references and technical documentation).

The other two times are easy to compute:

* the first, $\tau_h$, is the time of first hit with the boundary of the domain $C$ along the current ray $x(t)=x^{(i)}+(t-t_i)v^{(i)}$ for $t>t_i$. This guarantees that the trajectory stays in $C$ and that if the path meets a boundary, it bounces against it.
* the second, $\tau_r$, is a *refreshment time* sampled from an exponential distribution with a fixed rate. This guarantees full exploration of $C$ (see BPS paper for details).

Note that in the Wu and Robert's *Generalized Bouncy Particle Sampler* (GBPS), no refreshment is needed.

#### Computing a new velocity (BPS)

*Below we discuss the case of the BPS, the computations can be different for different samplers (such as the ZZ) but the essence of the method is the same.*

As mentioned above, we take $\tau = \min(\tau_b, \tau_h, \tau_r)$. Depending on the case, three actions can be taken

1. a **bounce** with $\tau = \tau_b$ where the new velocity is obtained by specular reflection against the tangent to the gradient of the log-likelihood at the point $x(\tau_b)$,
2. a **boundary bounce** with $\tau=\tau_{h}$ where the new velocity is obtained by specular reflection against the tangent to the boundary at the point of hit $x(\tau_h)$,
3. a **refreshment** with $\tau=\tau_r$ where the new velocity is drawn from a reference process such as a spherical Gaussian.

The update of the velocity goes as follows for the BPS (specular reflection):

\begin{equation}
    v \leftarrow v - 2\langle \nabla U(x), v\rangle{\nabla U(x)\over \|\nabla U(x)\|^2}.
\end{equation}

The figure below illustrates the specular reflexion, starting at the red point and going along the current ray (red, dashed line), we have a new event corresponding to a bounce or a hit (blue dot). In both cases, a specular reflection is executed (blue dashed line). The black line represents the tangent to either the boundary at that point or to the log-likelihood depending on the case.

![](assets/BPS.svg)

In Wu and Robert's Generalized Bouncy Particle Sampler, the update of the velocity for a standard "bounce" event, is a bit different and integrates a draw from a spherical gaussian which removes the need for refreshment (see references). This algorithm is implemented in the toolbox under the name "GBPS".

### Putting the pieces together

The simple global sampler can be expressed as follows:

> 1. Initialize $(x^{(0)}, v^{(0)})$ and $T$ the trajectory length
> 2. For $i=1,2,\dots$, consider the ray $x^{(i-1)}+t v^{(i-1)}$ for $t>0$
>     1. Simulate $\tau_b$ from an IPP along the ray
>     1. Compute $\tau_h$, simulate $\tau_r$ and let $\tau=\min(\tau_h,\tau_r,\tau_b)$
>     1. Following the case in (b.) compute the new velocity $v^{(i)}$
>     1. Store the new triple $(t_{i-1}+\tau,\, x^{(i-1)}+\tau v^{(i-1)},\, v^{(i)})$
>     1. if $t_i \ge T$ stop.
> 3. Return the path: $\{(t_i, x^{(i)}, v^{(i)})\}_{i=0,1,\dots}$

Following this representation, here are the key files of the code:

* A way to sample from an IPP:  [**ippsampler.jl**](https://github.com/alan-turing-institute/PDMP.jl/blob/master/src/ippsampler.jl).
* A way to define the geometry and in particular to compute the next boundary hit when traveling along a given ray: [**geometry.jl**](https://github.com/alan-turing-institute/PDMP.jl/blob/master/src/geometry.jl).
* A way to define how the velocity needs to be updated (reflection, refreshments): [**kernels.jl**](https://github.com/alan-turing-institute/PDMP.jl/blob/master/src/kernels.jl).
* A way to store a path formed of triples and compute integrals along it: [**path.jl**](https://github.com/alan-turing-institute/PDMP.jl/blob/master/src/path.jl).
* A core loop: [**simulate.jl**](https://github.com/alan-turing-institute/PDMP.jl/blob/master/src/simulate.jl).

We describe those in details and give explanations as to how to expand the toolbox in the technical documentation part.

## Local Samplers

### Basics of factor graphs

PDMP samplers can be adapted to explore the structure of the target distribution if it factorizes according to a factor graph i.e.:

\begin{equation}
    \pi(x) \propto \prod_{f\in F} \gamma_f (x_f),
\end{equation}

where $\gamma_f$ are non-negative functions of the variables $x_f=(x_{f_1},x_{f_2},\dots)$, a subset of all the variables. A very simple example is a Hidden Markov Model corresponding to a factor graph in the form of a chain as illustrated below:

![](assets/chaingraph.svg)

Distributions that factorize according to that factor graph have the form:

\begin{equation}
    \pi(x) \propto \gamma_1(x_1,x_2)\gamma_2(x_2,x_3)\gamma_3(x_3,x_4).
\end{equation}

The idea behind the local samplers is to try to exploit the conditional dependence structure represented by the factor graph.

### Local BPS

A rough idea of how the local BPS works is that it corresponds to an interacting collection of global BPS samplers, one for each of the factors.
In essence, each iteration of the algorithm works as follows:

1. it picks a factor $f\in F$ following a priority queue,
1. a new event is computed for $x_f$ following a global BPS-type procedure,
1. the priority queue is updated for the entries corresponding to $f$, and all $f'\in F$ that share a variable with $f$.

The priority queue therefore has one entry for each factor. These entries correspond to first arrival times of IPPs corresponding to the factor.

## Sampling from an IPP

### Inversion

### Thinning

## References

* Alexandre Bouchard-Côté, Sebastian J. Vollmer and Arnaud Doucet, [*The Bouncy Particle Sampler: A Non-Reversible Rejection-Free Markov Chain Monte Carlo Method*](https://arxiv.org/abs/1510.02451), arXiv preprint, 2015.
* Joris Bierkens, Alexandre Bouchard-Côté, Arnaud Doucet, Andrew B. Duncan, Paul Fearnhead, Gareth Roberts and Sebastian J. Vollmer, [*Piecewise Deterministic Markov Processes for Scalable Monte Carlo on Restricted Domains*](https://arxiv.org/pdf/1701.04244.pdf), arXiv preprint, 2017.
* Joris Bierkens, Paul Fearnhead and Gareth Roberts, [*The Zig-Zag Process and Super-Efficient Sampling for Bayesian Analysis of Big Data*](https://arxiv.org/pdf/1607.03188.pdf), arXiv preprint, 2016.
* Changye Wu, Christian Robert, [*Generalized Bouncy Particle Sampler*](https://arxiv.org/pdf/1706.04781.pdf), arXiv preprint, 2017.
