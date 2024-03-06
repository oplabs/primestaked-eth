const fs = require("fs");
const path = require("path");

const csvGeneratedFile = path.resolve(__dirname + "../../../data/tx.gen.csv");
const jsonFile = path.resolve(__dirname + "../../../data/tx.gen.json");

async function main() {
  if (!fs.existsSync(csvGeneratedFile)) {
    console.error("Tx File not generated?", csvGeneratedFile);
    process.exit(1);
  }

  const transactions = fs
    .readFileSync(csvGeneratedFile)
    .toString()
    .split("\n")
    .filter((row) => row.length > 0)
    .map((row) => {
      const [to, data] = row.split(",");
      return {
        to,
        data,
        value: "0",
        contractMethod: null,
        contractInputsValues: null,
      };
    });

  const safeJson = {
    version: "1.0",
    chainId: "1",
    createdAt: parseInt(Date.now() / 1000),
    meta: {
      name: "Transactions Batch",
      description: "",
      txBuilderVersion: "1.16.1",
      createdFromSafeAddress: "0xEc574b7faCEE6932014EbfB1508538f6015DCBb0",
      createdFromOwnerAddress: "",
    },
    transactions,
  };

  fs.writeFileSync(jsonFile, JSON.stringify(safeJson, undefined, 2));
}

main()
  .catch((err) => {
    console.error(err);
    process.exit(1);
  })
  .then(() => process.exit(0));
