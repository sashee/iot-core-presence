import {connect} from "mqtt";

export const handler = async () => {
	const {IOT_ENDPOINT, CA, CERT, KEY, THING_NAME} = process.env;
	const opts = {
		host: IOT_ENDPOINT,
		protocol: "mqtts",
		protocolVersion: 5,
		clientId: THING_NAME,
		clean: true,
		key: KEY,
		cert: CERT,
		ca: CA,
		reconnectPeriod: 0,
	};

	const client = await new Promise((res, rej) => {
		const client = connect(opts);
		const handleConnect = () => {
			client.off("connect", handleConnect);
			client.off("error", handleError);
			res(client);
		};
		const handleError = () => {
			client.off("connect", handleConnect);
			client.off("error", handleError);
			rej();
		};
		client.on("connect", handleConnect);
		client.on("error", handleError);
	});

	console.log("CONNECTED");

	await new Promise((res, rej) => {
		client.publish(`$aws/things/${THING_NAME}/shadow/name/test/update`, JSON.stringify({state: {reported: {value: `testing at ${new Date()}`}}}), (err) => {
			if(err) {
				rej(err);
			}else {
				res();
			}
		});
	});

	console.log("published");

	await new Promise((res) => {
		client.end(res);
	});
};
