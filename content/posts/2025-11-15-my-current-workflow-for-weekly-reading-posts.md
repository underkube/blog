---
title: "My current workflow to create the weekly reading posts"
date: 2025-11-15T17:30:32+01:00
draft: false
categories:
  - Meta
  - Workflow
tags:
  - Raindrop.io
  - AI
  - Github
---

## My current workflow to create the weekly reading posts

Here is a breakdown of the simple, automated, and edited workflow I currently follow every week:

### 1. Capturing and Collecting Links

I use [Raindrop.io](https://raindrop.io) as a Google Chrome extension and mobile app to save the links I found interesting into a dedicated collection named **"00-current"**.
This collection is configured to be the default saving location for all new bookmarks.

### 2. Processing (Sunday)

* I export all the bookmarks saved in the "00-current" collection as a .txt file.
* I use Gemini to create the initial structured Markdown post. I input the exported links and instruct the model to:
    * Organize the links into relevant technical categories (Kubernetes, Cloud Native, DevOps, etc.).
    * Generate a brief, descriptive summary for each link.
    * Format the entire output using the standard Markdown required by this blog.

### 3. Review, Refine, and Publish

* I review and edit the AI-generated markdown draft to prevent hallucinations and ask Gemini to refine the post if so.
* I use the GitHub web editor (yes, I'm lazy) to create a PR with the final markdown file.
* I review the preview (I currently use Netlify for that) and refine it if needed.
* I merge the PR and the post is published (via GitHub actions)

To prepare for the next week, I move all the links that were just published from **"00-current"** to a collection named **"99-archive"** in raindrop for archiving purposes.

That's it!
