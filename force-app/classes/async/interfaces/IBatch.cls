global interface IBatch extends IJob {
  // Batch configuration
  IBatch setBatchSize(Integer batchSize);
  // Lifecycle
  void finish();
  Integer getDefaultBatchSize();
}
