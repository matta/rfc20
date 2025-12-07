# rfc20
Personal blog

## How to make a new post

1.  Create a new markdown file using Hugo:
    ```bash
    hugo new content/posts/my-new-post.md
    ```
    (Replace `my-new-post.md` with your desired filename.)
2.  Edit the newly created markdown file in the `content/posts/` directory.
3.  To generate the static site, run:
    ```bash
    ./generate.sh
    ```
    This will create the public files in the `public/` directory.
4.  To serve the site locally for preview, run:
    ```bash
    ./serve.sh
    ```
    This will typically serve the site at `http://localhost:1313`.
