This branch is no longer actively developed; Signal's additions to `boring` live on the `main` branch. However, because past versions of [libsignal][] depended on this branch rather than on specific tags, it has to stay live in order to not break existing external clients. (And, for the curious, we don't want to put any breaking changes on this branch because that would mess up those same clients' use of `cargo update`.)

[libsignal]: https://github.com/signalapp/libsignal/
