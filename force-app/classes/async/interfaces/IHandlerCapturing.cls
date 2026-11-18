global interface IHandlerCapturing extends IHandler {
  // Control how nested async jobs are captured when this handler creates them
  Enums.CaptureMode getCaptureMode(IJob parentJob, IJob childJob);
}
