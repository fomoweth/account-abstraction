const { execSync } = require("child_process");
const { readFileSync, existsSync, mkdirSync, writeFileSync } = require("fs");
const { dirname, join } = require("path");

/**
 * @description Extracts contract deployment data from run-latest.json (foundry broadcast output) and writes to deployments/json/{chainId}.json
 * @usage node script/utils/extract.js --chain <CHAIN-ID> --rpc-url <RPC-URL> [--name <SCRIPT-NAME>]
 * @dev	Modified from https://github.com/Uniswap/forge-chronicles/tree/6ba49a452a03b92c7a5b159fcb5013cdde687f67
 */
async function main() {
	const [chainId, rpcUrl, scriptName, forceFlag, skipJsonFlag] = validateInputs();

	const json = await generateJson(scriptName, chainId, rpcUrl, forceFlag, skipJsonFlag);
	if (!!json) generateMarkdown(json);
}

async function generateJson(scriptName, chainId, rpcUrl, force, skip) {
	// ========== PREPARE FILES ==========

	// previously extracted data
	const outputPath = join(__dirname, `../../deployments/json/${chainId}.json`);
	const outputDir = dirname(outputPath);
	if (!existsSync(outputDir)) mkdirSync(outputDir, { recursive: true });

	const output = JSON.parse(
		(existsSync(outputPath) && readFileSync(outputPath, "utf-8")) ||
			JSON.stringify({ chainId, latest: {}, history: [] })
	);

	// skipping JSON generation, using existing JSON file instead
	if (!!skip) {
		if (!Object.keys(output.latest).length) {
			console.error(`\nError: ${outputPath} does not exist\n`);
			process.exit(1);
		}

		return output;
	}

	// latest broadcast
	const deploymentsPath = join(__dirname, `../../broadcast/${scriptName}/${chainId}/run-latest.json`);
	const deployments = JSON.parse(readFileSync(deploymentsPath, "utf-8"));

	const { commit, timestamp, transactions } = deployments;

	// revert if commit processed
	if (output.history.find((h) => h.commit === commit) && !force) {
		console.error(`\nError: commit ${commit} already processed\n`);
		process.exit(1);
	}

	// generate Forge artifacts
	prepareArtifacts();

	// ========== UPDATE LATEST ==========

	const isDuplicate = (name, address, hash) => {
		for (const history of output.history) {
			if (history.contracts.hasOwnProperty(name)) {
				const historyContract = history.contracts[name];
				if (historyContract.address === address && historyContract.hash === hash) {
					return true;
				}
			}
		}

		return false;
	};

	const isTransparentUpgradeableProxy = (proxyType) => proxyType === "TransparentUpgradeableProxy";

	// filter CREATE transactions
	const createTransactions = transactions.reduce((acc, tx) => {
		if (
			tx.transactionType === "CREATE" ||
			tx.transactionType === "CREATE2" ||
			tx.function === "deployModule(bytes32,bytes,bytes)"
		) {
			acc.push({
				...tx,
				contractAddress: toChecksumAddress(tx.contractAddress),
				transaction: {
					...tx.transaction,
					from: toChecksumAddress(tx.transaction.from),
					to: toChecksumAddress(tx.transaction.to),
				},
				additionalContracts: tx.additionalContracts.map((ctx) => ({
					...ctx,
					address: toChecksumAddress(ctx.address),
				})),
			});
		}

		return acc;
	}, []);

	const contracts = createTransactions
		.reduce(
			(
				acc,
				{
					additionalContracts: ctx,
					arguments,
					contractAddress,
					contractName,
					hash,
					transaction: { from: deployer, input },
					transactionType,
				},
				idx
			) => {
				let factory;
				let salt = input.slice(0, 66);

				// for 'deployModule(bytes32,bytes,bytes)' transactions
				if (transactionType === "CALL") {
					factory = contractAddress;
					contractAddress = ctx.find(({ transactionType: type }) => type === "CREATE2").address;
					contractName = getName(contractAddress, rpcUrl);
					salt = arguments[0];
					arguments = arguments[2].slice(2);
				}

				// CASE: TransparentUpgradeableProxy
				if (!!isTransparentUpgradeableProxy(contractName)) {
					console.warn(`\nSkipping proxy contract: ${contractName}(${contractAddress})\n`);
					return acc;
				}

				// CASE: contract already processed
				if (!!isDuplicate(contractName, contractAddress, hash)) {
					console.warn(`\nSkipping duplicate contract: ${contractName}(${contractAddress})\n`);
					return acc;
				}

				if (!output.latest.hasOwnProperty(contractName)) {
					const createTransaction = createTransactions
						.slice(idx + 1)
						.find(
							(tx) =>
								!!isTransparentUpgradeableProxy(tx.contractName) &&
								toChecksumAddress(tx.arguments[0]) === contractAddress
						);

					// CASE: new upgradeable contract
					if (!!createTransaction) {
						const proxyAddress = createTransaction.contractAddress;

						const deployment = filterProperties({
							address: proxyAddress,
							deployer,
							hash: createTransaction.hash,
							implementation: contractAddress,
							proxyAdmin: getProxyAdmin(proxyAddress, rpcUrl),
							proxyType: createTransaction.contractName,
							salt,
							version: getVersion(proxyAddress, rpcUrl),
						});

						output.latest[contractName] = {
							...deployment,
							timestamp,
							commit,
						};

						return acc.concat({
							contractName,
							...deployment,
							input: {
								constructor: getConstructorInputs(getABI(contractName), arguments),
								initializer: createTransaction.arguments[2],
							},
						});
					}
				} else {
					// CASE: existing upgradeable contract (new implementation)
					if (!!isTransparentUpgradeableProxy(output.latest[contractName].proxyType)) {
						const { address: proxyAddress, hash: proxyHash, proxyType } = output.latest[contractName];

						// CASE: mismatched proxy implementations
						if (getImplementation(proxyAddress, rpcUrl) !== contractAddress) {
							console.error(
								`\nError: mismatched implementations for ${contractName}(${contractAddress})\n`
							);
							process.exit(1);
						}

						const deployment = filterProperties({
							address: proxyAddress,
							deployer,
							hash: proxyHash,
							implementation: contractAddress,
							proxyAdmin: getProxyAdmin(proxyAddress, rpcUrl),
							proxyType,
							salt,
							version: getVersion(proxyAddress, rpcUrl),
						});

						output.latest[contractName] = {
							...deployment,
							timestamp,
							commit,
						};

						return acc.concat({
							contractName,
							...deployment,
							input: {
								constructor: getConstructorInputs(getABI(contractName), arguments),
							},
						});
					}
				}

				// CASE: new & existing non-upgradeable contracts
				const deployment = filterProperties({
					address: contractAddress,
					deployer,
					factory,
					hash,
					salt,
					version:
						contractName === "Vortex"
							? getAccountVersion(contractAddress, rpcUrl)
							: getVersion(contractAddress, rpcUrl),
				});

				output.latest[contractName] = {
					...deployment,
					timestamp,
					commit,
				};

				return acc.concat({
					contractName,
					...deployment,
					input: {
						constructor: getConstructorInputs(getABI(contractName), arguments),
					},
				});
			},
			[]
		)
		.sort((a, b) => (a.contractName.toLowerCase() < b.contractName.toLowerCase() ? -1 : 1))
		.reduce((acc, { contractName, ...rest }) => ({ ...acc, [contractName]: rest }), {});

	// ========== PREPEND TO HISTORY ==========

	if (!Object.keys(contracts).length) {
		console.log("\nNew contracts not found\n");
		return;
	}

	output.latest = Object.keys(output.latest)
		.sort((a, b) => (a.toLowerCase() < b.toLowerCase() ? -1 : 1))
		.reduce((acc, contractName) => ({ ...acc, [contractName]: output.latest[contractName] }), {});

	output.history.push({ contracts, timestamp, commit });

	// sort record history by timestamp
	output.history.sort((a, b) => b.timestamp - a.timestamp);

	// write to file
	writeFileSync(outputPath, JSON.stringify(output, null, 4), "utf8");

	return output;
}

function generateMarkdown(input) {
	const projectUrl = getProjectUrl();
	const projectName = getProjectName();

	let output = `# ${projectName}\n\n`;
	output += `\n### Table of Contents\n- [Summary](#summary)\n- [Contracts](#contracts)\n\t- `;
	output += Object.keys(input.latest)
		.map((contractName) => `[${contractName}](#${contractName.toLowerCase()})`)
		.join("\n\t- ");

	output += `\n\n## Summary\n\n<table>\n<tr>\n\t<th>Contract</th>\n\t<th>Address</th>\n\t<th>Version</th>\n</tr>\n`;

	output += Object.entries(input.latest)
		.map(
			([contractName, { address, version }]) =>
				`<tr>\n\t<td>${getContractLinkAnchor(projectUrl, contractName)}</td>\n\t<td>${getEtherscanLinkAnchor(
					input.chainId,
					address
				)}</td>\n\t<td>${version || "N/A"}</td>\n</tr>`
		)
		.join("\n");
	output += `</table>\n`;

	output += `\n## Contracts\n\n`;

	output += Object.entries(input.latest)
		.map(
			([contractName, { address, hash, timestamp }]) =>
				`### ${contractName}\n\nAddress: ${getEtherscanLinkMd(
					input.chainId,
					address
				)}\n\nTransaction Hash: ${getEtherscanLinkMd(input.chainId, hash, "tx")}\n\n${formatTimestamp(
					timestamp
				)}`
		)
		.join("\n\n---\n\n");

	writeFileSync(join(__dirname, `../../deployments/${input.chainId}.md`), output, "utf-8");
}

function getConstructorInputs(abi, arguments) {
	const inputs = {};

	const constructor = abi.find(({ type }) => type === "constructor");

	if (!!constructor && !!Array.isArray(arguments)) {
		if (constructor.inputs.length !== arguments.length) {
			console.error(`\nError: constructor inputs and arguments mismatched\n`);
			process.exit(1);
		}

		constructor.inputs.forEach((input, index) => {
			const formatName = (v) => (v.startsWith("_") ? v.slice(1) : v.endsWith("_") ? v.slice(0, -1) : v);

			const name = formatName(input.name);
			const argument = arguments[index];

			if (input.type === "tuple") {
				// if input is a mapping, extract individual key value pairs
				inputs[name] = {};

				// trim the brackets and split by comma
				const data = argument.slice(1, argument.length - 2).split(", ");

				for (let i = 0; i < input.components.length; i++) {
					inputs[name][formatName(input.components[i].name)] = data[i];
				}
			} else {
				inputs[name] = argument;
			}
		});
	} else if (!!constructor && typeof arguments === "string") {
		for (let i = 0; i < arguments.length / 64; i++) {
			const argument = arguments.slice(i * 64, (i + 1) * 64);

			inputs[i] = execSync(`cast parse-bytes32-address 0x${argument}`, { encoding: "utf-8" })
				.trim()
				.replaceAll('"', "");
		}
	}

	return inputs;
}

function getContractLinkAnchor(baseUrl, contractName) {
	const name = contractName.toLowerCase();
	let path;
	if (name.includes("factory")) {
		path = `factories/${contractName}`;
	} else if (name.includes("executor")) {
		path = `modules/executors/${contractName}`;
	} else if (name.includes("fallback")) {
		path = `modules/fallbacks/${contractName}`;
	} else if (name.includes("validator")) {
		path = `modules/validators/${contractName}`;
	} else {
		path = contractName;
	}

	return `<a href="${baseUrl}/blob/main/src/${path}.sol" target="_blank">${contractName}</a>`;
}

function getEtherscanLink(chainId, address, slug = "address") {
	switch (parseInt(chainId)) {
		case 1:
			return `https://etherscan.io/${slug}/${address}`;
		case 11155111:
			return `https://sepolia.etherscan.io/${slug}/${address}`;
		case 5:
			return `https://goerli.etherscan.io/${slug}/${address}`;
		case 10:
			return `https://optimistic.etherscan.io/${slug}/${address}`;
		case 11155420:
			return `https://sepolia-optimistic.etherscan.io/${slug}/${address}`;
		case 137:
			return `https://polygonscan.com/${slug}/${address}`;
		case 80002:
			return `https://amoy.polygonscan.com/${slug}/${address}`;
		case 8453:
			return `https://basescan.org/${slug}/${address}`;
		case 84532:
			return `https://sepolia.basescan.org/${slug}/${address}`;
		case 42161:
			return `https://arbiscan.io/${slug}/${address}`;
		case 421614:
			return `https://sepolia.arbiscan.io/${slug}/${address}`;
		default:
			throw new Error(`Unsupported chain: ${chainId}`);
	}
}

function getEtherscanLinkMd(chainId, address, slug = "address") {
	return `[${address}](${getEtherscanLink(chainId, address, slug)})`;
}

function getEtherscanLinkAnchor(chainId, address, slug = "address") {
	return `<a href="${getEtherscanLink(chainId, address, slug)}" target="_blank">${address}</a>`;
}

function prepareArtifacts() {
	execSync("forge build");
}

function getProjectName() {
	return execSync(`git remote get-url origin | cut -d '/' -f 5 | cut -d '.' -f 1`, { encoding: "utf-8" })
		.trim()
		.replaceAll("_", "-")
		.split("-")
		.map((word) => word.charAt(0).toUpperCase() + word.slice(1))
		.join(" ");
}

function getProjectUrl() {
	return execSync(`git remote get-url origin`, { encoding: "utf-8" })
		.trim()
		.replace(/\.git$/, "");
}

function toChecksumAddress(address) {
	try {
		return execSync(`cast to-check-sum-address ${address}`, { encoding: "utf-8" }).trim();
	} catch (e) {
		return null;
	}
}

function getImplementation(proxyAddress, rpcUrl) {
	try {
		return execSync(
			`cast storage ${proxyAddress} 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url ${rpcUrl} | cast parse-bytes32-address`,
			{ encoding: "utf-8" }
		)
			.trim()
			.replaceAll('"', "");
	} catch (e) {
		return null;
	}
}

function getProxyAdmin(proxyAddress, rpcUrl) {
	try {
		return execSync(
			`cast storage ${proxyAddress} 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103 --rpc-url ${rpcUrl} | cast parse-bytes32-address`,
			{ encoding: "utf-8" }
		)
			.trim()
			.replaceAll('"', "");
	} catch (e) {
		return null;
	}
}

function getEIP712Domain(contractAddress, rpcUrl) {
	try {
		return execSync(
			`cast call ${contractAddress} 'eip712Domain()((bytes1,string,string,uint256,address,bytes32,uint256[]))' --rpc-url ${rpcUrl}`,
			{ encoding: "utf-8" }
		)
			.trim()
			.replaceAll('"', "");
	} catch (e) {
		return null;
	}
}

function getAccountId(contractAddress, rpcUrl) {
	try {
		return execSync(`cast call ${contractAddress} 'accountId()(string)' --rpc-url ${rpcUrl}`, {
			encoding: "utf-8",
		})
			.trim()
			.replaceAll('"', "");
	} catch (e) {
		return null;
	}
}

function getAccountName(contractAddress, rpcUrl) {
	const accountId = getAccountId(contractAddress, rpcUrl);
	return accountId
		.split(".")
		.slice(0, 2)
		.map((word) => word.charAt(0).toUpperCase() + word.slice(1))
		.join(" ");
}

function getAccountVersion(contractAddress, rpcUrl) {
	const accountId = getAccountId(contractAddress, rpcUrl);
	return accountId.split(".").slice(2).join(".");
}

function getName(contractAddress, rpcUrl) {
	try {
		return execSync(`cast call ${contractAddress} 'name()(string)' --rpc-url ${rpcUrl}`, { encoding: "utf-8" })
			.trim()
			.replaceAll('"', "");
	} catch (e) {
		return null;
	}
}

function getVersion(contractAddress, rpcUrl) {
	try {
		return execSync(`cast call ${contractAddress} 'version()(string)' --rpc-url ${rpcUrl}`, { encoding: "utf-8" })
			.trim()
			.replaceAll('"', "");
	} catch (e) {
		return null;
	}
}

function getABI(contractName, outDir = "out") {
	const outPath = join(__dirname, `../../${outDir}/${contractName}.sol/${contractName}.json`);

	if (!existsSync(outPath)) {
		console.error(`\nError: contract ABI not found: ${contractName}\n`);
		process.exit(1);
	}

	const out = readFileSync(outPath, "utf8");
	const { abi } = JSON.parse(out);

	return abi;
}

function filterProperties(obj) {
	return Object.keys(obj).reduce((acc, key) => (!!obj[key] ? { ...acc, [key]: obj[key] } : acc), {});
}

function formatTimestamp(timestamp) {
	return new Date(timestamp * 1000).toUTCString().replace("GMT", "UTC");
}

function printHelp() {
	console.log(
		"\nUsage: node --env-file=.env script/utils/extract.js --chain <CHAIN_ID>\n\nOptions:\n\t-c, --chain\tChain ID of the network where the script to be executed\n\t-r, --rpc-url\tRPC URL used to fetch onchain data via 'force cast'\n\t-n, --name\tName of the script to be executed\n\t-f, --force\tForce the generation of the json file with the same commit\n\t-s, --skip-json\tSkips the JSON generation and creates the markdown file using an existing JSON file\n"
	);
}

function validateInputs() {
	execSync("source .env");

	const args = process.argv.slice(2);
	if (args[0] === "-h" || args[0] === "--help") {
		printHelp();
		process.exit(0);
	}

	let chainId;
	let rpcUrl;
	let scriptName = "Deploy.s.sol";
	let forceFlag = false;
	let skipJsonFlag = false;

	for (let i = 0; i < args.length; i++) {
		switch (args[i]) {
			case "-c":
			case "--chain":
				if (i + 1 < args.length && args[i + 1].charAt(0) !== "-") {
					chainId = args[i + 1];
					i++;
					break;
				} else {
					console.error(
						"\nError: --chain flag requires the chain id of the network where the script to be executed\n"
					);
					process.exit(1);
				}

			case "-r":
			case "--rpc-url":
				if (i + 1 < args.length && args[i + 1].charAt(0) !== "-") {
					rpcUrl = args[i + 1];
					i++;
					break;
				} else {
					console.error("\nError: --rpc-url flag requires an RPC URL\n");
					process.exit(1);
				}

			case "-n":
			case "--name":
				if (i + 1 < args.length && args[i + 1].charAt(0) !== "-") {
					scriptName = args[i + 1];
					if (scriptName && !scriptName.endsWith(".s.sol")) scriptName += ".s.sol";
					i++;
					break;
				} else {
					console.error("\nError: --name flag requires the name of the script to be executed\n");
					process.exit(1);
				}

			case "-f":
			case "-force":
				forceFlag = true;
				break;

			case "-s":
			case "--skip-json":
				skipJsonFlag = true;
				break;

			default:
				printHelp();
				process.exit(1);
		}
	}

	if (!existsSync(join(__dirname, `../${scriptName}`))) {
		console.error(`\nError: script/${scriptName || "<scriptName>"} does not exist\n`);
		process.exit(1);
	}

	return [chainId, rpcUrl, scriptName, forceFlag, skipJsonFlag];
}

main();
