---
title: "Why your build cache keeps missing"
slug: build-cache-misses
date: 2026-05-14
updated: 2026-05-20
author:
  name: Priya Ramanathan
  email: priya@example.com
tags:
  - build-systems
  - caching
  - performance
draft: false
summary: >
  A cache that never hits is worse than no cache at all, because you pay to
  maintain it. Four reasons a content-addressed build cache misses, and how to
  tell them apart.
cover:
  image: /images/photos/workshop-bench.jpg
  alt: A workbench seen from above
---

# Why your build cache keeps missing

A build cache that misses every time is not neutral. You pay for the hashing, the upload,
and the storage, and you get none of the time back. Before tuning anything, find out
*which* of the four common causes you have.

## 1. A timestamp is in the key

The most common cause. Something in the input set changes on every checkout: a generated
file with the build date in it, a lockfile rewritten by the installer, or a `.git`
directory pulled in by an over-broad glob.

Print the key inputs and diff two consecutive runs. If a file differs whose contents
should not have, that file is the cache.

## 2. The environment is part of the key, and it moves

Compiler versions, locale, and the absolute path of the workspace all leak into output.
Systems that hash the environment to stay correct will miss whenever the runner image
changes — which, on a hosted runner, is often.

## 3. The key is right and the store is empty

Distinguish a key mismatch from a store miss before changing anything. A store that
evicts after 24 hours will look exactly like a bad key to anyone reading only the hit
rate.

## 4. Nothing is cacheable

Some tasks genuinely have an input set the size of the repository. Splitting the task is
the fix; there is no cache configuration that helps.

## Telling them apart

| Symptom                                   | Likely cause |
| ----------------------------------------- | ------------ |
| Key differs between identical checkouts   | 1            |
| Key differs only across runners           | 2            |
| Key matches, no entry found               | 3            |
| Key differs after any commit at all       | 4            |

Start with the key. It is cheap to print, and it eliminates half the possibilities in one
run.
