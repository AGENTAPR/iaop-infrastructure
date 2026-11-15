<#import "template.ftl" as layout>
<#import "passkeys.ftl" as passkeys>
<@layout.registrationLayout displayMessage=!messagesPerField.existsError('username','password') displayInfo=true; section>
    <#if section = "header">
        ${msg("loginAccountTitle")}
    <#elseif section = "form">
        <div id="kc-form">
          <div id="kc-form-wrapper">
            <#if realm.password>
                <p class="av-subtitle">${msg("avSignInSubtitle")}</p>
                <form id="kc-form-login" class="av-form" onsubmit="login.disabled = true; return true;" action="${url.loginAction}" method="post">
                    <#if !usernameHidden??>
                        <div class="av-field">
                            <label class="av-label" for="username"><#if !realm.loginWithEmailAllowed>${msg("username")}<#elseif !realm.registrationEmailAsUsername>${msg("usernameOrEmail")}<#else>${msg("email")}</#if></label>

                            <input tabindex="2" id="username" class="av-input" name="username" value="${(login.username!'')}"  type="text"
                                   autofocus autocomplete="${(enableWebAuthnConditionalUI?has_content)?then('username webauthn', 'username')}"
                                   aria-invalid="<#if messagesPerField.existsError('username','password')>true</#if>"
                                   dir="ltr"
                            />

                            <#if messagesPerField.existsError('username','password')>
                                <span id="input-error" class="av-field-error" aria-live="polite">
                                        ${kcSanitize(messagesPerField.getFirstError('username','password'))?no_esc}
                                </span>
                            </#if>
                        </div>
                    </#if>

                    <div class="av-field">
                        <label class="av-label" for="password">${msg("password")}</label>

                        <div class="av-input-wrap" dir="ltr">
                            <input tabindex="3" id="password" class="av-input" name="password" type="password" autocomplete="current-password"
                                   aria-invalid="<#if messagesPerField.existsError('username','password')>true</#if>"
                            />
                            <button class="av-eye" type="button" aria-label="${msg("showPassword")}" tabindex="4" data-av-eye>
                                <svg class="av-eye-open" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
                                <svg class="av-eye-closed" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" hidden><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"/><line x1="1" y1="1" x2="23" y2="23"/></svg>
                            </button>
                        </div>

                        <#if usernameHidden?? && messagesPerField.existsError('username','password')>
                            <span id="input-error" class="av-field-error" aria-live="polite">
                                    ${kcSanitize(messagesPerField.getFirstError('username','password'))?no_esc}
                            </span>
                        </#if>
                    </div>

                    <#if realm.rememberMe && !usernameHidden??>
                        <div class="av-remember">
                            <label>
                                <#if login.rememberMe??>
                                    <input tabindex="5" id="rememberMe" name="rememberMe" type="checkbox" checked> ${msg("rememberMe")}
                                <#else>
                                    <input tabindex="5" id="rememberMe" name="rememberMe" type="checkbox"> ${msg("rememberMe")}
                                </#if>
                            </label>
                        </div>
                    </#if>

                    <div class="av-actions">
                        <#if realm.resetPasswordAllowed>
                            <div class="av-reset-row">
                                <a class="av-reset" tabindex="6" href="${url.loginResetCredentialsUrl}">${msg("doForgotPassword")}</a>
                            </div>
                        </#if>
                        <input type="hidden" id="id-hidden-input" name="credentialId" <#if auth.selectedCredential?has_content>value="${auth.selectedCredential}"</#if>/>
                        <input tabindex="7" class="av-submit" name="login" id="kc-login" type="submit" value="${msg("doLogIn")}"/>
                    </div>
                    <p class="av-legal">${msg("avLegalPre")} <span class="av-legal-link">${msg("avTermsLink")}</span> ${msg("avLegalAnd")} <span class="av-legal-link">${msg("avPrivacyLink")}</span>.</p>
                </form>
            </#if>
            </div>
        </div>
        <@passkeys.conditionalUIData />
        <script>
            document.querySelectorAll('[data-av-eye]').forEach(function (btn) {
                btn.addEventListener('click', function () {
                    var input = document.getElementById('password');
                    var open = btn.querySelector('.av-eye-open');
                    var closed = btn.querySelector('.av-eye-closed');
                    if (!input) return;
                    var show = input.type === 'password';
                    input.type = show ? 'text' : 'password';
                    if (open) open.hidden = show;
                    if (closed) closed.hidden = !show;
                    btn.setAttribute('aria-label', show ? '${msg("hidePassword")}' : '${msg("showPassword")}');
                });
            });
        </script>
    <#elseif section = "info" >
        <div class="av-get-started">
            <hr class="av-divider" />
            <h2 class="av-get-started-title">${msg("avGetStartedTitle")}</h2>
            <p class="av-get-started-body">${msg("avGetStartedPre")}
                <#if url.registrationUrl??><a class="av-get-started-link" href="${url.registrationUrl}">${msg("avSignUp")}</a><#else><span class="av-get-started-link">${msg("avSignUp")}</span></#if>.
            </p>
        </div>
    <#elseif section = "socialProviders" >
        <#if realm.password && social?? && social.providers?has_content>
            <div id="kc-social-providers" class="${properties.kcFormSocialAccountSectionClass!}">
                <hr/>
                <h2>${msg("identity-provider-login-label")}</h2>

                <ul class="${properties.kcFormSocialAccountListClass!} <#if social.providers?size gt 3>${properties.kcFormSocialAccountListGridClass!}</#if>">
                    <#list social.providers as p>
                        <li>
                            <a data-once-link data-disabled-class="${properties.kcFormSocialAccountListButtonDisabledClass!}" id="social-${p.alias}"
                                    class="${properties.kcFormSocialAccountListButtonClass!} <#if social.providers?size gt 3>${properties.kcFormSocialAccountGridItem!}</#if>"
                                    type="button" href="${p.loginUrl}">
                                <#if p.iconClasses?has_content>
                                    <i class="${properties.kcCommonLogoIdP!} ${p.iconClasses!}" aria-hidden="true"></i>
                                    <span class="${properties.kcFormSocialAccountNameClass!} kc-social-icon-text">${p.displayName!}</span>
                                <#else>
                                    <span class="${properties.kcFormSocialAccountNameClass!}">${p.displayName!}</span>
                                </#if>
                            </a>
                        </li>
                    </#list>
                </ul>
            </div>
        </#if>
    </#if>

</@layout.registrationLayout>
