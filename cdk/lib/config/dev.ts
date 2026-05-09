import { GetRicherConfig } from './types';

export const devConfig: GetRicherConfig = {
  environment: 'dev',

  lambda: {
    memorySize: 1024,
    timeout: 30
  },

  monitoring: {
    scheduleExpression: 'cron(0 6 * * ? *)',
    releaseLookbackHours: 2160
  }
};
