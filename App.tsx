import { createElement, useEffect, useState } from 'react';
import { ActivityIndicator, Platform, StyleSheet, View } from 'react-native';
import { Asset } from 'expo-asset';
import { StatusBar } from 'expo-status-bar';
import { WebView } from 'react-native-webview';

const solarSystemHtml = require('./assets/systeme-solaire-3d.html');

export default function App() {
  const [uri, setUri] = useState<string | null>(null);

  useEffect(() => {
    let active = true;

    async function loadAsset() {
      const asset = Asset.fromModule(solarSystemHtml);
      await asset.downloadAsync();
      if (active) setUri(asset.localUri ?? asset.uri);
    }

    loadAsset();
    return () => {
      active = false;
    };
  }, []);

  return (
    <View style={styles.root}>
      <StatusBar style="light" />
      {uri && Platform.OS === 'web' ? (
        createElement('iframe', {
          src: uri,
          title: 'Système solaire 3D',
          style: {
            border: 0,
            width: '100%',
            height: '100%',
            backgroundColor: '#11143f',
          },
        })
      ) : uri ? (
        <WebView
          source={{ uri }}
          style={styles.webview}
          originWhitelist={['*']}
          javaScriptEnabled
          domStorageEnabled
          allowFileAccess
          allowingReadAccessToURL={uri}
          bounces={false}
          overScrollMode="never"
          scrollEnabled={false}
          showsHorizontalScrollIndicator={false}
          showsVerticalScrollIndicator={false}
          setSupportMultipleWindows={false}
        />
      ) : (
        <View style={styles.loader}>
          <ActivityIndicator />
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: '#11143f',
  },
  webview: {
    flex: 1,
    backgroundColor: '#11143f',
  },
  loader: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#11143f',
  },
});
