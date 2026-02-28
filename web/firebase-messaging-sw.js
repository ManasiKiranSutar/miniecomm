importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyDwNmFd-YesEtYbWhKF4XZ3WknWBUrXLJ4",
  authDomain: "YOUR_AUTH_DOMAIN",
  projectId: "miniecomm-848f7",
  storageBucket: "miniecomm-848f7.firebasestorage.app",
  messagingSenderId: "YOUR_SENDER_ID",
  appId: "1:329887582191:ios:be5c49a789cceba6ac181a",

});

const messaging = firebase.messaging();