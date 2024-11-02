/* eslint-disable @next/next/no-img-element */
import './main.scss';
import '../styles/base.css';
import '../styles/responsive.css';
import Head from 'next/head';
import { useEffect } from 'react';
import 'react-loading-skeleton/dist/skeleton.css';
import { SkeletonTheme } from 'react-loading-skeleton';
import { Web3ModalProvider } from '@/context/Web3Modal';

export default function App({ Component, pageProps }) {
  useEffect(() => {
    // Add bootstrap js
    require('bootstrap/dist/js/bootstrap.bundle.min.js');

    // Remove the default stylesheet
    const styles = document.querySelector('#stitches');

    if (styles) {
      styles.remove();
    }
  }, []);

  return (
    <>
      <Head>
        <link rel="icon" href="/favicon.ico" />

        <meta charSet="UTF-8" />
        <meta httpEquiv="X-UA-Compatible" content="IE=edge" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <meta name="title" content="Stake & Hold Storm" />
        <meta
          name="description"
          content="Reward Dashboard for STORM Stakers and Holders."
        />

        {/* Facebook */}
        <meta property="og:type" content="website" />
        <meta property="og:url" content="https://vault.winterstorm.finance" />
        <meta property="og:title" content="Stake & Hold Storm" />
        <meta
          property="og:description"
          content="Reward Dashboard for STORM Stakers and Holders."
        />
        <meta
          property="og:image"
          content="https://vault.winterstorm.finance/static/images/logo_with_words.png"
        />

        {/* Twitter */}
        <meta property="twitter:card" content="summary_large_image" />
        <meta
          property="twitter:url"
          content="https://vault.winterstorm.finance"
        />
        <meta property="twitter:title" content="Stake Storm" />
        <meta
          property="twitter:description"
          content="Winter is here, the Storm is upon us."
        />
        <meta
          property="twitter:image"
          content="https://vault.winterstorm.finance/static/images/logo_with_words.png"
        />
      </Head>

      <Web3ModalProvider>
        <SkeletonTheme baseColor="#1A273B" highlightColor="#5C7C9D">
          <Component {...pageProps} />
        </SkeletonTheme>
      </Web3ModalProvider>

      <footer className="footer">
        {/* Subscribe Form */}
        <section id="subscribe" className="subscribe_section global_outer">
          <div className="subscribe_global_inner global_inner">
            <div className="subscribe_content">
              <h2 id="community" style={{ fontFamily: 'Iceberg' }}>
                Join The Community!
              </h2>
              <p style={{ fontFamily: 'Iceberg' }}>
                Follow us on our Official Channels to never miss important
                updates and announcements!
              </p>
              <div>
                <ul>
                  <div className="footer_link_social">
                    <div className="social_icon_list flex flex_wrap justify_center mt_3">
                      <a
                        target="_blank"
                        href="https://discord.com/invite/ZBcywm82S6">
                        <img src="discord.png" alt="" />
                      </a>
                      <a target="_blank" href="https://t.me/winterstorm_Fi">
                        <img src="telegram.png" alt="" />
                      </a>
                      <a
                        target="_blank"
                        href="https://twitter.com/intent/follow?screen_name=WinterStorm_Fi">
                        <img src="x1.png" alt="" />
                      </a>
                    </div>
                  </div>
                </ul>
              </div>
            </div>
          </div>
        </section>

        {/* Copyright Section */}
        <section className="footer_copyright global_outer">
          <div className="footer_copyright_inner global_inner">
            <div className="legal_links">
              <ul>
                <div className="footer_community_social">
                  <h2>Join us on:</h2>
                  <div className="social_icon_list flex flex_wrap justify_center mt_3">
                    <a
                      target="_blank"
                      href="https://discord.com/invite/ZBcywm82S6">
                      <img src="discord.png" alt="" />
                    </a>
                    <a target="_blank" href="https://t.me/winterstorm_Fi">
                      <img src="telegram.png" alt="" />
                    </a>
                    <a
                      target="_blank"
                      href="https://twitter.com/intent/follow?screen_name=WinterStorm_Fi">
                      <img src="x1.png" alt="" />
                    </a>
                  </div>
                </div>
              </ul>
            </div>
            <div
              className="copyright"
              style={{ paddingTop: '4%', color: '#fff' }}>
              &copy; Copyright 2024 Winter Storm. All Rights Reserved.
            </div>
          </div>
        </section>
      </footer>
    </>
  );
}
