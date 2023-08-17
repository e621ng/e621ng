// config/webpack/rules/vue.js
const { VueLoaderPlugin } = require('vue-loader')
const { DefinePlugin } = require('webpack')

module.exports = {
  module: {
    rules: [
      {
        test: /\.vue|\.vue\.erb$/,
        loader: 'vue-loader',
        options: {
          compilerOptions: {
            whitespace: "preserve",
          }
        },
      },
    ]
  },
  plugins: [
    new VueLoaderPlugin(),
    new DefinePlugin({
      __VUE_OPTIONS_API__: true,
      __VUE_PROD_DEVTOOLS__: false,
    })
  ],
  resolve: {
    extensions: ['.vue'],
  }
}
