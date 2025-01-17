import * as vscode from 'vscode';
import { Middleware } from "vscode-languageclient";
import { ThunkThunk, DidSaveCb, HandleDiagnosticsCallback } from './WagsiExt/TSTypes';


export function activate(context: vscode.ExtensionContext) {
	let ext = vscode.extensions.getExtension('nwolverson.ide-purescript');
	if (!ext) {
		console.warn("IDE PureScript Not Installed. This won't work as expected.");
		return;
	}
	let importedApi = ext ? ext.exports : { setMiddleware: () => { } };
	const outputChannel = vscode.window.createOutputChannel("wagsi");
	outputChannel.appendLine('Wagsi has been activated.');
	let didSaveCallbacks: Record<string, DidSaveCb> = {};
	let handleDiagnosticsCallbacks: Record<string, HandleDiagnosticsCallback> = {};
	let diagnosticsBeginCallbacks: Record<string, ThunkThunk> = {};
	let diagnosticsEndCallbacks: Record<string, ThunkThunk> = {};

	let middleware: Middleware = {
		didSave(this, data, next) {
			console.log("THIS MW was called");
			for (const eff of Object.values(didSaveCallbacks)) {
				eff(data)();
			}
			next(data);
		},
		handleDiagnostics(this, uri, diagnostics, next) {
			for (const eff of Object.values(handleDiagnosticsCallbacks)) {
				eff({ uri, diagnostics })();
			}
			return next(uri, diagnostics);
		},
	};

	let startLoopCallbacks: Record<string, ThunkThunk> = {};

	let startLoop = vscode.commands.registerCommand('wagsi.startLoop', () => {
		outputChannel.appendLine('Starting loop.');
		for (const eff of Object.values(startLoopCallbacks)) {
			outputChannel.appendLine('Invoking callback.');
			eff()();
		}
	});

	context.subscriptions.push(startLoop);
	let stopLoopCallbacks: Record<string, ThunkThunk> = {};

	let stopLoop = vscode.commands.registerCommand('wagsi.stopLoop', () => {
		for (const eff of Object.values(stopLoopCallbacks)) {
			eff()();
		}
	});

	context.subscriptions.push(stopLoop);

	importedApi.registerMiddleware(middleware);
	importedApi.setDiagnosticsBegin(() => {
		for (const eff of Object.values(diagnosticsBeginCallbacks)) {
			eff()();
		}
	});
	importedApi.setDiagnosticsEnd(() => {
		for (const eff of Object.values(diagnosticsEndCallbacks)) {
			eff()();
		}
	});
	require('./bundle').main({
		didSaveCallbacks, handleDiagnosticsCallbacks, startLoopCallbacks, stopLoopCallbacks, diagnosticsBeginCallbacks, diagnosticsEndCallbacks, outputChannel, launchCompilation: () => {
			vscode.commands.executeCommand("purescript.build");
		}
	})();
	outputChannel.appendLine('Invoke the start loop command to start the Wagsi loop.');
}

// this method is called when your extension is deactivated
export function deactivate() { }
