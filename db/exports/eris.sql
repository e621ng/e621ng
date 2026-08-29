SELECT images.post_id,
       images.avglf1,
       images.avglf2,
       images.avglf3,
       images.sig,
       images.updated_at
FROM images
ORDER BY images.post_id
