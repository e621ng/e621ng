const { webpackConfig, merge } = require('@rails/webpacker')
const vueConfig = require('./loaders/vue')

const customConfig = {
  resolve: {
    extensions: ['.css']
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
  externals: {
    jquery: "jQuery"
  }
}

module.exports = merge(vueConfig, webpackConfig, customConfig)
