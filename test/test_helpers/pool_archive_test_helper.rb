module PoolArchiveTestHelper
  def start_pool_archive_transaction
    PoolArchive.connection.begin_transaction joinable: false
  end

  def rollback_pool_archive_transaction
    PoolArchive.connection.rollback_transaction
  end
end
