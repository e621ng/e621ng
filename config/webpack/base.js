const { webpackConfig, merge } = require('@rails/webpacker')
const babelConfig = require('@rails/webpacker/package/rules/babel')
const vueConfig = require('./loaders/vue')

const customConfig = {
  resolve: {
    extensions: ['.css'],
    alias: {
      "jquery": "jquery/src/jquery",
    },
  },
  module: {
    rules: [
      {
        test: /\.erb$/,
        loader: 'rails-erb-loader'
      }
    ]
  },
  output: {
    library: ["Danbooru"]
  },
  optimization: {
    runtimeChunk: false
  },
  target: ['web', 'es5']
}

// Force babel-loader to transpile vue
babelConfig.exclude = /node_modules\/(?!(@vue|vue-loader)\/).*/;
babelConfig.include.push(/node_modules\/(@vue|vue-loader)\//);

module.exports = merge(vueConfig, webpackConfig, customConfig)
