import { Construct } from 'constructs';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as iam from 'aws-cdk-lib/aws-iam';

export interface ApiGatewayConstructProps {
  lambdaFunction: lambda.IFunction;
}

export class ApiGatewayConstruct extends Construct {
  public readonly api: apigateway.RestApi;

  constructor(scope: Construct, id: string, props: ApiGatewayConstructProps) {
    super(scope, id);

    this.api = new apigateway.RestApi(this, 'Api', {
      restApiName: 'GetRicher API',
      description: 'GetRicher Lambda API',
      endpointConfiguration: {
        types: [apigateway.EndpointType.REGIONAL]
      },
      deployOptions: {
        stageName: 'prod',
        metricsEnabled: true,
        loggingLevel: apigateway.MethodLoggingLevel.INFO,
        dataTraceEnabled: true
      }
    });

    const lambdaIntegration = new apigateway.LambdaIntegration(props.lambdaFunction, {
      proxy: true
    });

    // /hello route
    const helloResource = this.api.root.addResource('hello');
    helloResource.addMethod('GET', lambdaIntegration);

    // /api catch-all
    const apiResource = this.api.root.addResource('api');
    apiResource.addMethod('ANY', lambdaIntegration);
    const proxyResource = apiResource.addResource('{proxy+}');
    proxyResource.addMethod('ANY', lambdaIntegration);

    props.lambdaFunction.grantInvoke(new iam.ServicePrincipal('apigateway.amazonaws.com'));
  }
}
