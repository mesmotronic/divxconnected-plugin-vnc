/**
 * ConnectedVNC Plug-in for DivX Connected
 */

var dctk;

function onKeyEvent(event)
{
	switch(event.buttonId)
	{
		case dcKeyEvent.BUTTON_ID_BACK:
			if (window.history.length) window.history.back();
			break;
	}
}

function onLoadComplete()
{
	dctk = connected.toolkit;
	dctk.logicalWidth = 640;
	dctk.logicalHeight = 480;
	
	// Root panel
	
	var rootPanel = dctk.createPanelCtrl("root", true);
	rootPanel.width = 640;
	rootPanel.height = 480;
	rootPanel.onUnhandledKeyEvent = onKeyEvent;
	rootPanel.backgroundImg.src = "chrome://connected/content/new_back.jpg";
	rootPanel.backgroundImg.async = false;
	rootPanel.backgroundStyle = dctkIElement.BACKGROUND_STYLE_IMAGE;
	
	dctk.rootPanel = rootPanel;
	
	// URL
	
	var urlLabel = dctk.createLabelCtrl("urlLabel", true);
	urlLabel.setRect(0, 0, 640, 50); // left, bottom, right, top
	urlLabel.textColor.rgb = 0xFFFFFF;
	urlLabel.textColor.a = 64;
	urlLabel.fontSize = 15;
	urlLabel.text = "labs.mesmotronic.com/connectedvnc";
	urlLabel.align = dctkLabel.TS_CENTER;
	urlLabel.valign = dctkLabel.TS_TOP;
	rootPanel.addChild(urlLabel);
	
	// Login panel
	
	var loginPanel = dctk.createPanelCtrl("loginPanel", true);
	loginPanel.setRect(140, 115, 500, 365); // left, bottom, right, top
	loginPanel.outlined = true;
	loginPanel.filled = true;
	loginPanel.color.rgb = 0x000000;
	loginPanel.color.a = 192;
	loginPanel.onUnhandledKeyEvent = onKeyEvent;
	rootPanel.addChild(loginPanel);
	
	var logoImage = dctk.createImageCtrl("logoImage", true);
	logoImage.setRect(90, 160, 132, 225); // left, bottom, right, top
    logoImage.img.src = "chrome://connected/content/icons/comp.png";
	loginPanel.addChild(logoImage);
	
	var titleLabel = dctk.createLabelCtrl("titleLabel", true);
	titleLabel.setRect(140, 190, 360, 220); // left, bottom, right, top
	titleLabel.textColor.rgb = 0xFFFFFF;
	titleLabel.fontSize = 36;
	titleLabel.text = "ConnectedVNC";
	titleLabel.align = dctkLabel.TS_LEFT;
	titleLabel.valign = dctkLabel.TS_MIDDLE;
	loginPanel.addChild(titleLabel);
	
	var subtitleLabel = dctk.createLabelCtrl("subtitleLabel", true);
	subtitleLabel.setRect(143, 160, 360, 195); // left, bottom, right, top
	subtitleLabel.textColor.rgb = 0x666666;
	subtitleLabel.fontSize = 12;
	subtitleLabel.text = "Version 1.0 / Press ENTER for keyboard";
	subtitleLabel.align = dctkLabel.TS_LEFT;
	subtitleLabel.valign = dctkLabel.TS_MIDDLE;
	loginPanel.addChild(subtitleLabel);
	
	var passwordLabel = dctk.createLabelCtrl("passwordLabel", true);
	passwordLabel.setRect(0, 115, 127, 150); // left, bottom, right, top
	passwordLabel.textColor.rgb = 0xCCCCCC;
	passwordLabel.fontSize = 22;
	passwordLabel.text = "Password:";
	passwordLabel.align = dctkLabel.TS_RIGHT;
	passwordLabel.valign = dctkLabel.TS_MIDDLE;
	loginPanel.addChild(passwordLabel);
	
	var passwordEdit = dctk.createEditCtrl("passwordEdit", true);
	passwordEdit.setRect(140, 120, 320, 145); // left, bottom, right, top
	passwordEdit.fontSize = 22;
	passwordEdit.numeric = false;
	passwordEdit.password = true;
	passwordEdit.text = getPassword();
	loginPanel.addChild(passwordEdit);
	
	var audioLabel = dctk.createLabelCtrl("audioLabel", true);
	audioLabel.setRect(0, 85, 127, 120); // left, bottom, right, top
	audioLabel.textColor.rgb = 0xCCCCCC;
	audioLabel.fontSize = 22;
	audioLabel.text = "Audio URL:";
	audioLabel.align = dctkLabel.TS_RIGHT;
	audioLabel.valign = dctkLabel.TS_MIDDLE;
	loginPanel.addChild(audioLabel);
	
	var audioEdit = dctk.createEditCtrl("audioEdit", true);
	audioEdit.setRect(140, 90, 320, 115); // left, bottom, right, top
	audioEdit.fontSize = 22;
	audioEdit.numeric = false;
	audioEdit.text = getAudio();
	loginPanel.addChild(audioEdit);
	
	var loginButton = dctk.createButtonCtrl("loginButton", true);
	loginButton.setRect(100, 35, 260, 65); // left, bottom, right, top
	loginButton.text = "Login";
	loginButton.fontSize = 22;
	loginButton.onSelect = onLoginButtonSelect;
	loginPanel.addChild(loginButton);	
	
	passwordEdit.topSibling = loginButton;
	passwordEdit.bottomSibling = audioEdit;
	audioEdit.topSibling = passwordEdit;
	audioEdit.bottomSibling = loginButton;
	loginButton.topSibling = audioEdit;
	loginButton.bottomSibling = passwordEdit;
	
	dctk.focusedElement = loginButton;
}

function onLoginButtonSelect(event)
{
	setPassword();
	setAudio();
	onLoginComplete();
}

function onLoginComplete()
{
	var desc = connected.createPageDescriptor();
	desc.uri = "ConnectedVNC.html";
	desc.pageType = dcIConnected.PT_HTML;
	desc.audioCapture = true;
	desc.htmlInputFocusMode = dcIPageDescriptor.FOCUS_MODE_OBJECT
	
	connected.loadFromPageDescriptor(desc);
}

function getPassword()
{
	var storage = connected.openStorage("ConnectedVNC", false);
	var password = storage.get("password")
	
	return password;
}

function setPassword()
{
	var passwordEdit = dctk.getElementById("passwordEdit");	
	var storage = connected.openStorage("ConnectedVNC", false);
	
	storage.set("password", passwordEdit.text);
}

function getAudio()
{
	var storage = connected.openStorage("ConnectedVNC", false);
	var audio = storage.get("audio")
	
	if (!audio || !audio.length) audio = "http://localhost:8000/stream.mp3";
	
	return audio;
}

function setAudio()
{
	var audioEdit = dctk.getElementById("audioEdit");	
	var storage = connected.openStorage("ConnectedVNC", false);
	
	storage.set("audio", audioEdit.text);
}
