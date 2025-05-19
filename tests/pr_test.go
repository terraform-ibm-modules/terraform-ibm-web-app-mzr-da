// Tests in this file are run in the PR pipeline and the continuous testing pipeline
package test

import (
	"os"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/stretchr/testify/assert"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/cloudinfo"
	"github.com/terraform-ibm-modules/ibmcloud-terratest-wrapper/testhelper"
)

const defaultExampleTerraformDir = "solutions/e2e"

// Need to use different regions per test to ensure there is no clash in SSH keys as ssh key value has to be unique per VPC region
const region1 = "us-south"
const region2 = "us-east"

var sharedInfoSvc *cloudinfo.CloudInfoService

func TestMain(m *testing.M) {
	sharedInfoSvc, _ = cloudinfo.NewCloudInfoServiceFromEnv("TF_VAR_ibmcloud_api_key", cloudinfo.CloudInfoServiceOptions{})

	// creating ssh keys
	tSsh := new(testing.T)
	rsaKeyPair, _ := ssh.GenerateRSAKeyPairE(tSsh, 4096)
	sshPublicKey := strings.TrimSuffix(rsaKeyPair.PublicKey, "\n") // removing trailing new lines
	sshPrivateKey := "<<EOF\n" + rsaKeyPair.PrivateKey + "EOF"
	if err := os.Setenv("TF_VAR_ssh_key", sshPublicKey); err != nil {
		tSsh.Fatalf("failed to set TF_VAR_ssh_key: %v", err) // pragma: allowlist secret
	}
	if err := os.Setenv("TF_VAR_ssh_private_key", sshPrivateKey); err != nil {
		tSsh.Fatalf("failed to set TF_VAR_ssh_private_key: %v", err) // pragma: allowlist secret
	}

	// use trial instance for tests
	if err := os.Setenv("TF_VAR_sm_service_plan", "trial"); err != nil {
		tSsh.Fatalf("failed to set TF_VAR_sm_service_plan: %v", err)
	}
	os.Exit(m.Run())
}

func setupOptions(t *testing.T, prefix string, dir string, region string) *testhelper.TestOptions {
	options := testhelper.TestOptionsDefaultWithVars(&testhelper.TestOptions{
		Testing:      t,
		TerraformDir: dir,
		Prefix:       prefix,
		Region:       region,
	})
	return options
}

func TestRunDefaultExample(t *testing.T) {
	t.Parallel()

	options := setupOptions(t, "webapp", defaultExampleTerraformDir, region1)

	output, err := options.RunTestConsistency()
	assert.Nil(t, err, "This should not have errored")
	assert.NotNil(t, output, "Expected some output")
}

func TestRunUpgradeExample(t *testing.T) {
	t.Parallel()

	options := setupOptions(t, "webapp-u", defaultExampleTerraformDir, region2)

	output, err := options.RunTestUpgrade()
	if !options.UpgradeTestSkipped {
		assert.Nil(t, err, "This should not have errored")
		assert.NotNil(t, output, "Expected some output")
	}
}
