module.exports = function (api) {
  var validEnv = ['development', 'test', 'production']
  var currentEnv = api.env()
  var isDevelopmentEnv = api.env('development')
  var isProductionEnv = api.env('production')
  var isTestEnv = api.env('test')
  const { moduleExists } = require('@rails/webpacker')

  if (!validEnv.includes(currentEnv)) {
    throw new Error(
      'Please specify a valid `NODE_ENV` or ' +
      '`BABEL_ENV` environment variables. Valid values are "development", ' +
      '"test", and "production". Instead, received: ' +
      JSON.stringify(currentEnv) +
      '.'
    )
  }

  return {
    presets: [
      isTestEnv && ['@babel/preset-env', { targets: { node: 'current' } }],
      (isProductionEnv || isDevelopmentEnv) && [
        '@babel/preset-env',
        {
          useBuiltIns: 'entry',
          modules: 'auto',
          forceAllTransforms: true,
          exclude: ['transform-typeof-symbol']
        }
      ],
      moduleExists('@babel/preset-typescript') && [
        '@babel/preset-typescript',
        { allExtensions: true, isTSX: true }
      ],
      moduleExists('@babel/preset-react') && [
        '@babel/preset-react',
        {
          development: isDevelopmentEnv || isTestEnv,
          useBuiltIns: true
        }
      ]
    ].filter(Boolean),
    plugins: [
      ['@babel/plugin-transform-runtime', { helpers: false }],
      isProductionEnv &&
      moduleExists('babel-plugin-transform-react-remove-prop-types') && [
        'babel-plugin-transform-react-remove-prop-types',
        { removeImport: true }
      ]
    ].filter(Boolean)
  }
}
