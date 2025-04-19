#!/usr/bin/env python3
import sys
import time
import argparse
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from urllib.parse import urlparse, parse_qs

def get_verification_code(auth_url, username, password):
    # Set up Chrome options
    chrome_options = Options()
    
    # Try with non-headless mode first, as E-Trade might have anti-bot measures
    chrome_options.add_argument("--no-sandbox")
    chrome_options.add_argument("--disable-dev-shm-usage")
    chrome_options.add_argument("--disable-blink-features=AutomationControlled")
    chrome_options.add_argument("--user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36")
    chrome_options.add_experimental_option("excludeSwitches", ["enable-automation"])
    chrome_options.add_experimental_option('useAutomationExtension', False)
    
    # Try to set up the Chrome driver
    try:
        from webdriver_manager.chrome import ChromeDriverManager
        from selenium.webdriver.chrome.service import Service
        service = Service(ChromeDriverManager().install())
        driver = webdriver.Chrome(service=service, options=chrome_options)
    except Exception as e:
        print(f"Error setting up Chrome driver with webdriver_manager: {e}", file=sys.stderr)
        print("Falling back to default Chrome driver", file=sys.stderr)
        try:
            driver = webdriver.Chrome(options=chrome_options)
        except Exception as e:
            print(f"Error setting up Chrome driver: {e}", file=sys.stderr)
            return None
    
    # Set window size to a reasonable desktop size
    driver.set_window_size(1280, 800)
    
    try:
        print(f"Opening auth URL: {auth_url}", file=sys.stderr)
        driver.get(auth_url)
        
        # Take a screenshot to debug
        try:
            screenshot_path = "/tmp/etrade_auth_page.png"
            driver.save_screenshot(screenshot_path)
            print(f"Saved screenshot to {screenshot_path}", file=sys.stderr)
        except Exception as e:
            print(f"Failed to save screenshot: {e}", file=sys.stderr)
            
        # Check for common errors in the page
        try:
            if "400" in driver.title or "Error" in driver.title:
                print(f"Error page detected. Title: {driver.title}", file=sys.stderr)
                print(f"Current URL: {driver.current_url}", file=sys.stderr)
                print("Page content:", file=sys.stderr)
                print(driver.page_source[:1000] + "...", file=sys.stderr)
                
                # Try to navigate directly to the E-Trade login page
                print("Attempting to navigate directly to E-Trade login page...", file=sys.stderr)
                driver.get("https://us.etrade.com/e/t/user/login")
                time.sleep(5)
                
                # Take another screenshot
                try:
                    screenshot_path = "/tmp/etrade_login_page.png"
                    driver.save_screenshot(screenshot_path)
                    print(f"Saved screenshot to {screenshot_path}", file=sys.stderr)
                except Exception as e:
                    print(f"Failed to save screenshot: {e}", file=sys.stderr)
        except Exception as e:
            print(f"Error checking for error page: {e}", file=sys.stderr)
        
        # Print the current URL and title
        print(f"Current URL: {driver.current_url}", file=sys.stderr)
        print(f"Page title: {driver.title}", file=sys.stderr)
        
        # Wait for the page to load completely
        time.sleep(5)
        
        # Try different selectors for the login form
        login_selectors = [
            {"username": "user_orig", "password": "pwd_orig", "button": "logon_button"},
            {"username": "username", "password": "password", "button": "login-button"},
            {"username": "username", "password": "password", "button": "submit"},
            {"username": "user", "password": "password", "button": "login"}
        ]
        
        login_successful = False
        
        for selectors in login_selectors:
            try:
                # Check if the username field exists
                if len(driver.find_elements(By.ID, selectors["username"])) > 0:
                    print(f"Found login form with username field ID: {selectors['username']}", file=sys.stderr)
                    
                    # Fill in the username and password
                    driver.find_element(By.ID, selectors["username"]).send_keys(username)
                    driver.find_element(By.ID, selectors["password"]).send_keys(password)
                    
                    # Click the login button
                    driver.find_element(By.ID, selectors["button"]).click()
                    
                    login_successful = True
                    print("Login form submitted", file=sys.stderr)
                    break
            except Exception as e:
                print(f"Tried selector set {selectors} but got error: {e}", file=sys.stderr)
                continue
        
        if not login_successful:
            print("Could not find login form with known selectors. Trying XPath...", file=sys.stderr)
            try:
                # Try to find input fields by type
                username_field = driver.find_element(By.XPATH, "//input[@type='text' or @type='email']")
                password_field = driver.find_element(By.XPATH, "//input[@type='password']")
                submit_button = driver.find_element(By.XPATH, "//button[@type='submit'] | //input[@type='submit']")
                
                username_field.send_keys(username)
                password_field.send_keys(password)
                submit_button.click()
                
                login_successful = True
                print("Login form submitted using XPath selectors", file=sys.stderr)
            except Exception as e:
                print(f"Failed to find login form using XPath: {e}", file=sys.stderr)
        
        if not login_successful:
            print("Failed to log in. Checking if we're already on the authorization page...", file=sys.stderr)
        
        # Wait for the authorization page to load
        time.sleep(5)
        
        # Try different selectors for the authorize button
        authorize_selectors = ["authorize_form", "authorize-form", "oauth-authorize"]
        authorize_button_selectors = ["authorize_button", "authorize-button", "approve", "accept"]
        
        authorization_successful = False
        
        # First check if we're already on a page with the oauth_verifier parameter
        current_url = driver.current_url
        if "oauth_verifier" in current_url:
            print(f"Already redirected to callback with verification code", file=sys.stderr)
            authorization_successful = True
        else:
            # Try to find and click the authorize button
            for form_id in authorize_selectors:
                try:
                    if len(driver.find_elements(By.ID, form_id)) > 0:
                        print(f"Found authorization form with ID: {form_id}", file=sys.stderr)
                        
                        # Try each possible button ID
                        for button_id in authorize_button_selectors:
                            try:
                                if len(driver.find_elements(By.ID, button_id)) > 0:
                                    driver.find_element(By.ID, button_id).click()
                                    authorization_successful = True
                                    print(f"Clicked authorize button with ID: {button_id}", file=sys.stderr)
                                    break
                            except Exception as e:
                                print(f"Failed to click button with ID {button_id}: {e}", file=sys.stderr)
                        
                        if authorization_successful:
                            break
                except Exception as e:
                    print(f"Failed to find form with ID {form_id}: {e}", file=sys.stderr)
            
            # If we still haven't found the button, try XPath
            if not authorization_successful:
                try:
                    # Try to find a button that looks like an authorize button
                    authorize_button = driver.find_element(By.XPATH, "//button[contains(text(), 'Authorize') or contains(text(), 'Approve') or contains(text(), 'Accept')]")
                    authorize_button.click()
                    authorization_successful = True
                    print("Clicked authorize button using XPath", file=sys.stderr)
                except Exception as e:
                    print(f"Failed to find authorize button using XPath: {e}", file=sys.stderr)
        
        # Wait for the redirect to happen
        time.sleep(5)
        
        # Get the current URL (which should be the callback URL with the verification code)
        callback_url = driver.current_url
        print(f"Final URL: {callback_url}", file=sys.stderr)
        
        # Take a final screenshot
        try:
            screenshot_path = "/tmp/etrade_final_page.png"
            driver.save_screenshot(screenshot_path)
            print(f"Saved final screenshot to {screenshot_path}", file=sys.stderr)
        except Exception as e:
            print(f"Failed to save final screenshot: {e}", file=sys.stderr)
        
        # Parse the URL to extract the verification code
        parsed_url = urlparse(callback_url)
        query_params = parse_qs(parsed_url.query)
        
        if 'oauth_verifier' in query_params:
            verifier = query_params['oauth_verifier'][0]
            print(f"Verification code: {verifier}", file=sys.stderr)
            return verifier
        else:
            # Check if the verification code is in the page content (sometimes it's displayed on the page)
            try:
                page_source = driver.page_source
                # Look for text that might contain the verification code
                import re
                verifier_match = re.search(r'verification code[:\s]+([a-zA-Z0-9]+)', page_source, re.IGNORECASE)
                if verifier_match:
                    verifier = verifier_match.group(1)
                    print(f"Found verification code in page content: {verifier}", file=sys.stderr)
                    return verifier
            except Exception as e:
                print(f"Error searching for verification code in page content: {e}", file=sys.stderr)
            
            print("Error: Could not find verification code in the callback URL", file=sys.stderr)
            print(f"URL parameters: {query_params}", file=sys.stderr)
            return None
    
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        return None
    
    finally:
        driver.quit()

def main():
    parser = argparse.ArgumentParser(description='Get E-Trade verification code')
    parser.add_argument('auth_url', help='The authorization URL')
    parser.add_argument('username', help='E-Trade username')
    parser.add_argument('password', help='E-Trade password')
    
    args = parser.parse_args()
    
    verifier = get_verification_code(args.auth_url, args.username, args.password)
    
    if verifier:
        # Print just the code to stdout for easy capture by the shell script
        print(verifier)
    else:
        sys.exit(1)

if __name__ == "__main__":
    main()
