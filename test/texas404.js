const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { expect } = require("chai");

describe("Texas404", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deploy() {
    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await ethers.getSigners();
    const TexasPoker = await ethers.getContractFactory("TexasPoker");
    const libInstance = await TexasPoker.deploy();
    // await libInstance;
    console.log("Library Address--->" + libInstance)

    const Texas404 = await ethers.getContractFactory("Texas404",{ libraries: { TexasPoker: libInstance } });
    const texas = await Texas404.deploy();

    return { texas,  owner, otherAccount };
  }

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      const { texas, owner } = await loadFixture(deploy);

      expect(await texas.owner()).to.equal(owner.address);
    });
  });

});
