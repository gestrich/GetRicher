import { Construct } from 'constructs';
import * as iam from 'aws-cdk-lib/aws-iam';
import { Stack } from 'aws-cdk-lib';

export class GitHubActionsConstruct extends Construct {
  public readonly deployRoleArn: string;

  constructor(scope: Construct, id: string) {
    super(scope, id);

    const stack = Stack.of(this);
    const qualifier = 'hnb659fds'; // default CDK bootstrap qualifier

    const oidcProvider = iam.OpenIdConnectProvider.fromOpenIdConnectProviderArn(
      this,
      'GitHubOidcProvider',
      `arn:aws:iam::${stack.account}:oidc-provider/token.actions.githubusercontent.com`
    );

    const deployRole = new iam.Role(this, 'DeployRole', {
      roleName: 'get-richer-github-actions-deploy',
      assumedBy: new iam.WebIdentityPrincipal(oidcProvider.openIdConnectProviderArn, {
        StringLike: {
          'token.actions.githubusercontent.com:sub': 'repo:gestrich/GetRicher:*'
        },
        StringEquals: {
          'token.actions.githubusercontent.com:aud': 'sts.amazonaws.com'
        }
      })
    });

    // Allow assuming CDK bootstrap roles so `cdk deploy` works from CI
    deployRole.addToPolicy(new iam.PolicyStatement({
      actions: ['sts:AssumeRole'],
      resources: [
        `arn:aws:iam::${stack.account}:role/cdk-${qualifier}-deploy-role-${stack.account}-${stack.region}`,
        `arn:aws:iam::${stack.account}:role/cdk-${qualifier}-file-publishing-role-${stack.account}-${stack.region}`,
        `arn:aws:iam::${stack.account}:role/cdk-${qualifier}-image-publishing-role-${stack.account}-${stack.region}`,
        `arn:aws:iam::${stack.account}:role/cdk-${qualifier}-lookup-role-${stack.account}-${stack.region}`,
      ]
    }));

    this.deployRoleArn = deployRole.roleArn;
  }
}
