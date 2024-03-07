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
    const lib = await TexasPoker.deploy();
    // await libInstance;
    console.log("Library Address--->" + lib)

    const Texas404 = await ethers.getContractFactory("Texas404",{ libraries: { TexasPoker: lib } });
    const texas = await Texas404.deploy();

    return { texas,  owner, otherAccount,lib };
  }

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      const { texas, owner } = await loadFixture(deploy);

      expect(await texas.owner()).to.equal(owner.address);
    });
  });

  describe("library", function () {
    it("library", async function () {
      const { lib } = await loadFixture(deploy);

      expect(await lib.uint2str(51)).to.equal("0x040x0d0x010x010x010x010x010x010x010x01");


      var val = 51;
      val = val * 52 + 50;
      val = val * 52 + 49;
      val = val * 52 + 48;
      val = val * 52 + 47;
      expect(await lib.uint2str(val)).to.equal("0x040x090x040x0a0x040x0b0x040x0c0x040x0d");
    });
  });

  describe("mint", function () {
    it("mint nft", async function () {
      const { texas, owner } = await loadFixture(deploy);

      await texas.mint(1);
      const balance = await texas.nftBalanceOf(owner.address);
      console.log("nft balance--->" + balance)
      expect(balance).to.equal(1);

      await texas.mint(3);
      const balance2 = await texas.nftBalanceOf(owner.address);
      console.log("nft balance--->" + balance2)
      expect(balance2).to.equal(4);
    });
  });

  describe("remint", function () {
    it("remint nft", async function () {
      const { texas, owner } = await loadFixture(deploy);

      await texas.mint(1);
      const balance = await texas.nftBalanceOf(owner.address);
      console.log("nft balance--->" + balance)
      expect(balance).to.equal(1);
      console.log(await texas.tokenURI(1));
      expect(await texas.minted()).to.equal(1);

      await texas.remint(1);
      const balance2 = await texas.nftBalanceOf(owner.address);
      console.log("nft balance--->" + balance2)
      expect(balance2).to.equal(1);
      console.log(await texas.tokenURI(2));
      expect(await texas.minted()).to.equal(2);

      await texas.remint(3);
      const balance3 = await texas.nftBalanceOf(owner.address);
      console.log("nft balance--->" + balance3)
      expect(balance3).to.equal(1);
      expect(await texas.minted()).to.equal(5);
      
      const url = await texas.tokenURI(5);
      console.log("token url--->" + url)
      console.log(await texas.card(5))
    });
  });


  describe("staking", function () {
    it("staking nft", async function () {
      const { texas, owner } = await loadFixture(deploy);

      await texas.mint(1);
      expect(await texas.nftBalanceOf(owner.address)).to.equal(1);

      await texas.staking([1]);
      expect(await texas.nftBalanceOf(owner.address)).to.equal(0);

      await texas.unstaking([1]);
      expect(await texas.nftBalanceOf(owner.address)).to.equal(1);
    });
  });

});
