//
//  NoteViewController.swift
//  Connect App
//
//  Created by devel on 7/12/16.
//  Copyright © 2016 Harloch. All rights reserved.
//

import UIKit
import Firebase

class NoteViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {
    
    
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    
    var ref:FIRDatabaseReference!
    var userArr: [UserData] = []
    var filtered:[NoteData] = []
    var noteArr: [NoteData] = []
    var userName: String?
    var photoURL: String?
    var searchActive : Bool = false
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        self.searchBar.delegate = self
        //self.tableView.allowsSelection = false
        self.tableView.dataSource = self
        self.tableView.delegate = self
        
        let myGroup = dispatch_group_create()
        
        ref = FIRDatabase.database().reference()
        let userID = FIRAuth.auth()?.currentUser?.uid
        let noteRef = ref.child("users").child(userID!).child("notes")
        
        CommonUtils.sharedUtils.showProgress(self.view, label: "Loading...")
        dispatch_group_enter(myGroup)
        noteRef.observeSingleEventOfType(.Value, withBlock: { (snapshot) in
            self.noteArr.removeAll()
            self.filtered.removeAll()
            self.userArr.removeAll()
            for childSnap in snapshot.children.allObjects {
                let snapData = childSnap as! FIRDataSnapshot
                let dic = snapData.value as! [String : String]
                for (key, value) in dic {
                    dispatch_group_enter(myGroup)
                    self.ref.child("users").child(key).observeSingleEventOfType(.Value, withBlock: { (snap) in
                        if snap.exists()
                        {
                            
                            let userFirstName = snapshot.value!["userFirstName"] as? String ?? (snapshot.value!["facebookData"] as? NSDictionary)?["userFirstName"] as? String ?? ""
                            let userLastName = snapshot.value!["userLastName"] as? String ?? (snapshot.value!["facebookData"] as? NSDictionary)?["userLastName"] as? String ?? ""
                            
                            var noImage = false
                            var image = UIImage(named: "no-pic.png")
                            if let base64String = snap.value!["image"] as! String! {
                                image = CommonUtils.sharedUtils.decodeImage(base64String)
                            } else {
                                noImage = true
                            }
                            
                            if snap.hasChild("facebookData") {
                                let facebookData = snap.value!["facebookData"]
                                let data = facebookData as! NSDictionary!
                                self.photoURL = data.valueForKey("profilePhotoURL") as! String!
                            }
                            else {
                                if snap.hasChild("twitterData") {
                                    let facebookData = snap.value!["twitterData"]
                                    let data = facebookData as! NSDictionary!
                                    self.photoURL = data.valueForKey("profile_image_url") as! String!
                                }
                                else {
                                    self.photoURL = ""
                                }
                            }
                            self.userName = userFirstName + " " + userLastName
                            
                            if self.photoURL == nil {
                                self.photoURL = ""
                            }
                            
                            if let email = snap.value!["email"] as? String {
                                let userData = UserData(userName: self.userName!, photoURL: self.photoURL!, uid: snap.key, image: image!, email: email, noImage: noImage)
                                let noteData = NoteData(user: userData, note: value, key: snapData.key)
                                self.noteArr.append(noteData)
                            } else {
                                let userData = UserData(userName: self.userName!, photoURL: self.photoURL!, uid: snap.key, image: image!, email: "test@test.com", noImage: noImage)
                                let noteData = NoteData(user: userData, note: value, key: snapData.key)
                                self.noteArr.append(noteData)
                            }
                            self.tableView.reloadData()
                        }
                        dispatch_group_leave(myGroup)
                    })
                }
            }
            dispatch_group_leave(myGroup)
        }) { (error) in
            print(error.localizedDescription)
            dispatch_group_leave(myGroup)
        }
        
        dispatch_group_notify(myGroup,  dispatch_get_main_queue()) {
            CommonUtils.sharedUtils.hideProgress()
        }
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func  preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }
    
    @IBAction func backBtnTapped(sender: UIButton) {
        //self.dismissViewControllerAnimated(true, completion: nil)
        self.navigationController?.popViewControllerAnimated(true)
    }
    
    func searchBarTextDidBeginEditing(searchBar: UISearchBar) {
        self.searchBar.showsCancelButton = true
        searchActive = true;
    }
    
    func searchBarTextDidEndEditing(searchBar: UISearchBar) {
        searchActive = false;
    }
    
    func searchBarCancelButtonClicked(searchBar: UISearchBar) {
        searchBar.text = ""
        searchBar.endEditing(true)
        searchActive = false;
        self.searchBar.showsCancelButton = false
        self.tableView.reloadData()
    }
    
    func searchBarSearchButtonClicked(searchBar: UISearchBar) {
        searchActive = false;
    }
    
    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        
        filtered = noteArr.filter { note in
            return note.getNote().lowercaseString.containsString(searchText.lowercaseString)
        }
        
        if searchText  == ""{
            self.searchActive = false
        }
        else {
            self.searchActive = true
        }
        self.tableView.reloadData()
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.searchBar.text != "" {
            return filtered.count
        }
        return noteArr.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("NoteCell") as! NoteTableViewCell
        
        if self.searchBar.text != "" {
            let noteData = filtered[indexPath.row]
            let userData = noteData.getUser()
            let note = noteData.getNote()
            cell.nameLabel.text = userData.getUserName()
            cell.noteLabel.text = note
            
            let imageExist = userData.imageExist()
            if imageExist {
                let image = userData.getImage()
                cell.photo.image = image
            } else {
                if !userData.getUserPhotoURL().isEmpty {
                    cell.photo.sd_setImageWithURL(NSURL(string: userData.getUserPhotoURL()), placeholderImage: UIImage(named: "no-pic.png"))
                }
            }
        } else {
            let noteData = noteArr[indexPath.row]
            let userData = noteData.getUser()
            let note = noteData.getNote()
            cell.nameLabel.text = userData.getUserName()
            cell.noteLabel.text = note
            
            let imageExist = userData.imageExist()
            if imageExist {
                let image = userData.getImage()
                cell.photo.image = image
            } else {
                if !userData.getUserPhotoURL().isEmpty {
                    cell.photo.sd_setImageWithURL(NSURL(string: userData.getUserPhotoURL()), placeholderImage: UIImage(named: "no-pic.png"))
                }
            }
        }
        
        if self.searchActive {
            
            
        }else {
            
        }
        
        
        
        return cell
    }
    
//    func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
//        CommonUtils.sharedUtils.hideProgress()
//    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath)
    {
        print("Index Path: ", indexPath.row)
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        
        if self.searchBar.text != "" {
            let noteData = filtered[indexPath.row]
            let friend = noteData.getUser()
            let note = noteData.getNote()
            
            AppState.sharedInstance.friend = friend
            
            let vc = self.storyboard?.instantiateViewControllerWithIdentifier("FriendPortalViewController") as! FriendPortalViewController!
            vc.selectedNote = noteData
            self.navigationController?.pushViewController(vc, animated: true)
            
        } else {
            let noteData = noteArr[indexPath.row]
            let friend = noteData.getUser()
            let note = noteData.getNote()
            
            AppState.sharedInstance.friend = friend
            
            let vc = self.storyboard?.instantiateViewControllerWithIdentifier("FriendPortalViewController") as! FriendPortalViewController!
            vc.selectedNote = noteData
            self.navigationController?.pushViewController(vc, animated: true)
        }
        
    }
    
    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
//        var noteData:NoteData
//        if self.searchBar.text != "" {
//            noteData = filtered[indexPath.row]
//        } else {
//            noteData = noteArr[indexPath.row]
//        }
//        
//        print(noteData.getUser().uid, " == ",  FIRAuth.auth()?.currentUser?.uid)
//        
//        if noteData.getUser().uid == (FIRAuth.auth()?.currentUser?.uid ?? "") {
//            return true
//        }
        return true
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle:   UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        
        var noteData:NoteData?
        if self.searchBar.text != "" {
            noteData = filtered[indexPath.row]
        } else {
            noteData = noteArr[indexPath.row]
        }
        
        if let note = noteData
            where (editingStyle == UITableViewCellEditingStyle.Delete)
        {
            
            tableView.beginUpdates()
            
            noteArr.removeAtIndex(indexPath.row)
            //filtered = filtered.removeEqualItems(noteData)
            
            filtered = filtered.filter { note in
                return note.getKey() != noteData!.getKey()
            }
            noteArr = noteArr.filter { note in
                return note.getKey() != noteData!.getKey()
            }
            
            ref.child("users").child(FIRAuth.auth()?.currentUser?.uid ?? "").child("notes").child(noteData!.getKey()).removeValue()
            
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Automatic)
            tableView.endUpdates()
            
        }
    }
}