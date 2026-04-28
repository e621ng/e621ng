# frozen_string_literal: true

# Exclude daily favorite_events partitions (favorite_events_YYYY_MM_DD) from structure dumps.
# The parent table is retained; child partitions are managed at runtime by FavoriteEventPartitionJob.
ActiveRecord::Tasks::DatabaseTasks.structure_dump_flags = ["--exclude-table=favorite_events_????_??_??"]
