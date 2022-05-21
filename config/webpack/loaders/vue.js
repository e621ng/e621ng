// config/webpack/rules/vue.js
const { VueLoaderPlugin } = require('vue-loader')
const { DefinePlugin } = require('webpack')

module.exports = {
  module: {
    rules: [
      {
        test: /\.vue$/,
        loader: 'vue-loader',
        options: {
          compilerOptions: {
            whitespace: "preserve",
            compatConfig: {
              MODE: 3
            }
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
    alias: {
      vue: '@vue/compat'
    },
  }
}
