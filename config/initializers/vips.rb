# frozen_string_literal: true

# libvips defaults to nproc threads per operation, in every web worker and job thread.
# VIPS_CONCURRENCY in the environment overrides this per container.
Vips.concurrency_set(1) if ENV["VIPS_CONCURRENCY"].blank?

# Each image is processed once, so the operation cache only pins memory.
Vips.cache_set_max(0)

# Only load the formats we accept. Unblocking a loader also unblocks its file/buffer/source variants.
Vips.block("VipsForeignLoad", true)
%w[VipsForeignLoadJpeg VipsForeignLoadPng VipsForeignLoadNsgif VipsForeignLoadWebp].each do |loader|
  Vips.block(loader, false)
end
