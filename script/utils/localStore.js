const fs = require('fs');
const path = require('path');

const storeFilePath = path.join(__dirname, '..', '..', '.localKeyValueStorage');

const localStore = () => {
	let storeData = null;

	const get = (key) => {
		if (typeof key !== 'string') {
			throw new Error("Key must be a string");
		}

		_loadFileToObjectOption();
		return storeData[key];
	}

	const put = (key, value) => {
		if (typeof key !== 'string' || typeof value !== 'string') {
			throw new Error("Key and value must be strings");
		}

		_loadFileToObjectOption();
		storeData[key] = value;
		_storeFileToObjectOption();
	}

	const del = (key) => {
		if (typeof key !== 'string') {
			throw new Error("Key must be a string");
		}

		_loadFileToObjectOption();
		delete storeData[key];
		_storeFileToObjectOption();
	}

	const _storeFileToObjectOption = () => {
		fs.writeFileSync(storeFilePath, JSON.stringify(storeData));
	}

	const _loadFileToObjectOption = () => {
		if (storeData != null) {
			return;
		}

		storeData = {};

		if (fs.existsSync(storeFilePath)) {
			storeData = JSON.parse(fs.readFileSync(storeFilePath, 'utf8'));
		}
	}

	return {
		get,
		put,
		del
	}
}

module.exports = localStore;

