require("@nomiclabs/hardhat-ethers");

async function main() {
  const CrunchKeys = await ethers.getContractFactory("CrunchKeys");
  console.log("Deploying CrunchKeys to ", network.name);

  const [account1] = await ethers.getSigners();

  const crunchKeys = await upgrades.deployProxy(
    CrunchKeys,
    [
      account1.address,
      BigInt("50000000000000000"),
      BigInt("25000000000000000"),
    ],
    {
      initializer: "initialize",
    },
  );
  await crunchKeys.waitForDeployment();

  console.log("CrunchKeys deployed to:", crunchKeys.target);

  process.exit();
}

main();
