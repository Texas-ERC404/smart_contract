const {
    loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { expect } = require("chai");

describe("Texas404Reward", function () {
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


        const Texas404 = await ethers.getContractFactory("Texas404", { libraries: { TexasPoker: lib } });
        const texas = await Texas404.deploy();

        const TexasReward = await ethers.getContractFactory("Texas404Reward");
        const reward = await TexasReward.deploy(texas);

        await texas.setRewardContract(reward);

        return { texas, owner, otherAccount, reward };
    }

    describe("Deployment", function () {
        it("Should set the right owner", async function () {
            const { texas, owner, reward } = await loadFixture(deploy);

            expect(await texas.owner()).to.equal(owner.address);
            expect(await reward.owner()).to.equal(owner.address);
            expect(await reward.texas()).to.equal(texas);
            expect(await texas.rewardAddr()).to.equal(reward);
        });
    });

    describe("claim", function () {
        it("claim by owner", async function () {
            const { texas, reward, otherAccount } = await loadFixture(deploy);

            await texas.transfer(reward, 10000000000000000000n);

            const balance = await texas.balanceOf(reward);
            expect(balance).to.equal(10000000000000000000n);

            await reward.claimByOwner(otherAccount.address, 1000000000000000000n, 1);
            const balance2 = await texas.balanceOf(otherAccount.address);
            expect(balance2).to.equal(1000000000000000000n);

            await expect(
                reward.claimByOwner(otherAccount.address, 1000000000000000000n, 1)
            ).to.be.revertedWith("nonce used");
        });

        it("claim with sign", async function () {
            const { texas, owner, reward, otherAccount } = await loadFixture(deploy);

            await texas.transfer(reward, 10000000000000000000n);

            const balance = await texas.balanceOf(reward);
            expect(balance).to.equal(10000000000000000000n);

            const td = {
                domain: {
                    name: "texas404",
                    version: '1.0',
                    chainId: await network.provider.send("eth_chainId"),
                    verifyingContract: await texas.rewardAddr()
                },
                types: {
                    Claim: [
                        { name: 'user', type: 'address' },
                        { name: 'value', type: 'uint256' },
                        { name: 'nonce', type: 'uint256' },
                    ]
                },
                message: {
                    user: otherAccount.address,
                    value: 1000000000000000000n,
                    nonce: 11
                }
            }

            const flatSig = await owner.signTypedData(td.domain, td.types, td.message);
            console.log("sig:" + flatSig);
            const splitSig = ethers.Signature.from(flatSig);
            console.log("v:" + splitSig.v);
            console.log("r:" + splitSig.r);
            console.log("s:" + splitSig.s);

            await reward.connect(otherAccount).claim(1000000000000000000n, 11, splitSig.v, splitSig.r, splitSig.s);
            const balance2 = await texas.balanceOf(otherAccount.address);
            expect(balance2).to.equal(1000000000000000000n);

            await expect(
                reward.claimByOwner(otherAccount.address, 1000000000n, 11)
            ).to.be.revertedWith("nonce used");
        });
    });


});
