import * as cdk from 'aws-cdk-lib/core';
import { Template } from 'aws-cdk-lib/assertions';
import { GetRicherStack } from '../lib/get-richer-stack';
import { devConfig } from '../lib/config/dev';

test('Lambda function created', () => {
  const app = new cdk.App();
  const stack = new GetRicherStack(app, 'TestStack', { config: devConfig });
  const template = Template.fromStack(stack);

  template.hasResourceProperties('AWS::Lambda::Function', {
    FunctionName: 'get-richer'
  });
});

test('API Gateway created', () => {
  const app = new cdk.App();
  const stack = new GetRicherStack(app, 'TestStack', { config: devConfig });
  const template = Template.fromStack(stack);

  template.resourceCountIs('AWS::ApiGateway::RestApi', 1);
});

test('DynamoDB table created', () => {
  const app = new cdk.App();
  const stack = new GetRicherStack(app, 'TestStack', { config: devConfig });
  const template = Template.fromStack(stack);

  template.hasResourceProperties('AWS::DynamoDB::Table', {
    TableName: 'get-richer'
  });
});
