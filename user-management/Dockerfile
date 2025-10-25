FROM rust:1.87-bullseye as builder
WORKDIR /usr/src/user-management

# Install build deps
RUN apt-get update && apt-get install -y pkg-config libssl-dev ca-certificates && rm -rf /var/lib/apt/lists/*

# Copy manifest and source
COPY Cargo.toml Cargo.lock* ./
COPY src ./src

# Build release
RUN cargo build --release

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=builder /usr/src/user-management/target/release/user-management /usr/local/bin/user-management
EXPOSE 8080
CMD ["/usr/local/bin/user-management"]
