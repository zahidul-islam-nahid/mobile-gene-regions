# syntax=docker/dockerfile:1
FROM mambaorg/micromamba:1.5.10

ARG MAMBA_DOCKERFILE_ACTIVATE=1
SHELL ["/bin/bash", "-lc"]

# --- Repo workspace ---
WORKDIR /opt/app
COPY --chown=mambauser:mambauser . /opt/app

# --- Create env from YAML (must include python=3.10, snakemake=7.32, pulp=2.7.0, blast, minimap2,
#     graphviz, r-base, julia=1.7.2, etc.) + git for cloning
RUN micromamba env create -n flanking-regions -f flanking-regions.yaml -y \
 && micromamba install -y -n flanking-regions -c conda-forge git \
 && micromamba clean -a -y

# --- Install legacy PanGraph (v0) into the env (Julia package) ---
RUN micromamba run -n flanking-regions julia -e 'using Pkg; \
    Pkg.add(PackageSpec(url="https://github.com/neherlab/pangraph.git", rev="v0")); \
    using PanGraph; Pkg.precompile()'

# --- Clone PanGraph v0 repo to use its CLI script ---
RUN micromamba run -n flanking-regions git clone --branch v0 --depth 1 \
      https://github.com/neherlab/pangraph.git /opt/app/pangraph

# --- Instantiate v0 repo project & patch missing deps (fixes StatsBase/AliasTables precompile) ---
RUN micromamba run -n flanking-regions julia -e 'using Pkg; \
    Pkg.activate("/opt/app/pangraph"); \
    Pkg.instantiate(); \
    Pkg.add(PackageSpec(name="StatsBase", version="0.34.4")); \
    Pkg.add("AliasTables"); \
    Pkg.precompile()'

# --- Provide a `pangraph` CLI wrapper with v1→v0 flag translation ---
RUN cat > /opt/conda/envs/flanking-regions/bin/pangraph <<'BASH' && chmod +x /opt/conda/envs/flanking-regions/bin/pangraph
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "build" ]]; then
  shift
  args=()
  while (( "$#" )); do
    case "$1" in
      -n) shift ;;            # v1-only; drop for v0
      *)  args+=("$1"); shift ;;
    esac
  done
  exec julia --project=/opt/app/pangraph /opt/app/pangraph/src/PanGraph.jl build "${args[@]}"
else
  exec julia --project=/opt/app/pangraph /opt/app/pangraph/src/PanGraph.jl "$@"
fi
BASH

# --- R plotting deps (best-effort; don’t fail image if a mirror hiccups) ---
RUN micromamba run -n flanking-regions Rscript scripts/install_libraries.R || true

# --- Writable bind points for data/output ---
USER root
RUN mkdir -p /data /output && chown -R mambauser:mambauser /data /output
USER mambauser

# --- PATH + default env ---
ENV PATH=/opt/conda/envs/flanking-regions/bin:$PATH
ENV MAMBA_DEFAULT_ENV=flanking-regions

# --- Default: show CLI help inside env ---
CMD ["micromamba", "run", "-n", "flanking-regions", "python", "analyze-flanking-regions.py", "--help"]

