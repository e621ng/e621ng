## Changes to use s3 backend for data
1. Set the values in `.env`
    ```
    DANBOORU_AWS_ACCESS_KEY_ID=example_access_key
    DANBOORU_AWS_SECRET_ACCESS_KEY=example_secret_key
    ```
2. Uncomment and edit a line to enable the s3 storage manager in `config/danbooro_default_config.rb` Set the bucket, s3 storage domain, and s3 options
    ```
    StorageManager::S3.new("bucket_name", base_url: "https://bucket_name.s3.amazonaws.com/", s3_options: {})
    ```
    if bucket is specified in url path and not subdomain add the s3_option: force_path_style: true and endpoint
    ```
    StorageManager::S3.new("bucket_name", base_url: "https://s3.amazonaws.com/", s3_options: {endpoint: "https://s3.amazonaws.com/", force_path_style: true})
    ```
3. Change default_base_path in `app/logical/storage_manager.rb`
    set value to "/"
    ```
    def default_base_path
        "/"
    end
    ```
    or set value to "/bucket_name" if the storage uses a path style
    ```
    def default_base_path
        "/bucket_name"
    end
    ```
4. Uncomment the line and set value in `config/environments/development.rb`
    ```
    config.active_storage.service = :amazon
    ```
5. Add s3 domains in `config/initializers/content_security_policy.rb`
    on the end add the domain used for s3 storage on the following lines 
    ```
    policy.object_src
    policy.media_src
    policy.img_src
    ```