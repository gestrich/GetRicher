import { GetRicherConfig } from './types';

export const devConfig: GetRicherConfig = {
  environment: 'dev',

  lambda: {
    memorySize: 1024,
    timeout: 30
  },

  monitoring: {
    scheduleExpression: 'rate(1 hour)',
    releaseLookbackHours: 2160
  }
};
