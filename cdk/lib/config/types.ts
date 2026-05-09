export interface GetRicherConfig {
  environment: 'dev' | 'staging' | 'prod';

  lambda: {
    memorySize: number;
    timeout: number;
    reservedConcurrentExecutions?: number;
  };

  monitoring: {
    scheduleExpression: string;
    releaseLookbackHours: number;
  };
}
