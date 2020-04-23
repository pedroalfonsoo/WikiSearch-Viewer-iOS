//
//  SearchResultsTableViewController.swift
//  WikiSearch&Viewer
//
//  Created by Pedro Alfonso on 4/20/20.
//  Copyright © 2020 Pedro Alfonso. All rights reserved.
//

import UIKit

class SearchResultsTableViewController: UITableViewController {
    
    private let searchBar: UISearchBar = {
        let searchBar = UISearchBar(frame: .zero)
        searchBar.showsCancelButton = true
        searchBar.placeholder = "Search on Wikipedia..."
        searchBar.searchTextField.backgroundColor = .white
           
        return searchBar
    }()
    
    private let tableFooterView: UIView = {
        let footerView = UIView(frame: .zero)
        let imageView = UIImageView()
        imageView.image = UIImage(named: "searchPicture")
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        footerView.addSubview(imageView)
        footerView.autoresizingMask = [.flexibleHeight]
        
        imageView.topAnchor.constraint(equalTo: footerView.topAnchor).isActive = true
        imageView.bottomAnchor.constraint(equalTo: footerView.bottomAnchor).isActive = true
        imageView.leftAnchor.constraint(equalTo: footerView.leftAnchor).isActive = true
        imageView.rightAnchor.constraint(equalTo: footerView.rightAnchor).isActive = true
        
        return footerView
    }()
    
    private var viewModel: SearchResultsViewModel
    private let wikiSearchService: WikiSearchService
    private var fetchMoreWikiPages: Bool = false
    
    init(wikiSearchService: WikiSearchService) {
        viewModel = SearchResultsViewModel(searchText: "", searchResults: nil)
        self.wikiSearchService = wikiSearchService
        
        super.init(nibName: nil, bundle: nil)
    }
       
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
       
    override func viewDidLoad() {
        super.viewDidLoad()
           
        setupView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.navigationBar.isHidden = false
        navigationItem.setHidesBackButton(true, animated: false)
    }
    
    private func setupView() {
        searchBar.delegate = self
        navigationItem.titleView = searchBar
        navigationController?.navigationBar.tintColor = .black
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.navigationBar.barStyle = .default
        navigationController?.navigationBar.setBackgroundImage(UIImage(named: "navigationBarBackground"),
                                                                   for: .default)
        setupTableView()
    }
    
    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(WikiPageTableViewCell.self, forCellReuseIdentifier:
            WikiPageTableViewCell.cellReuseIdentifier)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 57
        
        tableFooterView.frame = tableView.frame
        tableView.tableFooterView = tableFooterView
    }
    
    private func updateTableViewUI() {
        guard !(viewModel.searchResults?.isEmpty ?? true) else {
            showPopupAlert(title: "Search", message: "There are no results for \"\(searchBar.text ?? "")\"")
            return
        }
        
        tableView.isScrollEnabled = true
        tableView.tableFooterView = nil
        tableView.reloadDataWithAnimation(duration: 0.1)
    }
    
    private func fetchResults() {
        fetchMoreWikiPages = false
        showActivityIndicatory(style: .large, color: .black)
        
        wikiSearchService.fetchResults(viewModel.searchText,
                                       offset: viewModel.resultsOffset,
                                       resultsLimit: viewModel.offset) { [weak self] response in
            self?.fetchMoreWikiPages = true
            self?.stopActivityIndicatory()
            
            do {
                let searchResult = try response() as? WikiPageProperties

                
                if self?.viewModel.resultsOffset == 0 {
                    self?.viewModel = SearchResultsViewModel(searchText: self?.viewModel.searchText ?? "",
                                                             searchResults: searchResult?.query.pages.properties)
                } else {
                    self?.viewModel.updateSearchResultsWithOffset(offsetResults:
                        searchResult?.query.pages.properties)
                }

                DispatchQueue.main.async {
                    self?.updateTableViewUI()
                }
            } catch {
                self?.showPopupAlert(title: "Search Error", message: "Unable to retrieve result(s)")
            }
        }
    }
    
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.searchResults?.count ?? 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: WikiPageTableViewCell.cellReuseIdentifier,
                                                 for: indexPath) as! WikiPageTableViewCell
        
        guard let cellViewModel = viewModel.getCellViewModelForRow(indexPath.row) else {
            return UITableViewCell()
        }
        
        cell.prepareForReuse()
        cell.setupCellWithModel(cellViewModel)
        
        return cell
    }
    

    // MARK: - Table view delegates

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let searchResults = viewModel.searchResults else { return }
        
        let webContentViewController = WebContentViewController(urlToLoad: searchResults[indexPath.row].fullurl)
        webContentViewController.delegate = self
        
        navigationController?.pushViewController(webContentViewController, animated: true)
    }
    
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView.contentOffset.y > scrollView.contentSize.height - scrollView.frame.height,
            fetchMoreWikiPages,
            viewModel.resultsOffset < viewModel.limitOffset else { return }
             
        viewModel.incrementOffset()
        fetchResults()
    }
}
    
// MARK: - Search bar Delegates
    
extension SearchResultsTableViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let searchBarText = searchBar.text else { return }
        
        viewModel.setSearchToInitialState(searchText: searchBarText)
        fetchResults()
        searchBar.resignFirstResponder()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}


// MARK: - WebContentViewControllerDismissing Delegates

extension SearchResultsTableViewController: WebContentViewControllerDismissing {
    func dismissViewController() {
        navigationController?.popViewController(animated: true)
    }
}
