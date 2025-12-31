Read "Best practices for writing dockerfiles".

- FROM, WORKDIR, COPY, ADD, RUN, CMD.
- Using multi-stage builds for clean separation and efficiency
- minimizing image complexity at each build stage
- see dockerfile.test-multistage

- Naive approach (no multi-stage build): 857 MB
- Optimized approach: 150 MB
- Optimized (alpine): **28 MB**

- Can install on one image, then move install files to other machine
- add symlink from file locaiton to /usr/bin/program-name
  - or update PATH variable (start with new folder, followed by previous list)
- use "which" to find a binary's location
- use "ldd" to find dependencies of a binary
- ubuntu uses glibc, alpine uses musl. OS mismatch (binaries compiled for one compiler cannot run on the machine). Switched to debian:stable-slim
- musl is one of the reasons why alpine can be so small (5MB)
- clear package cache to save even more space
- One Layer rule: each RUN command is a new layer that can be cached. Must chain some commands (ex. apk update and apk add pkg) (called cache busting)

- Explicitly set a non-root user in dockerfile (containers run as root user by default)
- UID != 0 means its a non-root user.
- Distroless is even better than non-root user (cannot run code or read files since there is no shell)
  - Distroless also runs as non-root by default in many cases
- Distroless con: must copy over all libraries manually
