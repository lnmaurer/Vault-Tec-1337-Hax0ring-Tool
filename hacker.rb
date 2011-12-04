#!/usr/bin/ruby

#Vault-Tec 1337 Hax0ring Tool -- a program to aid hacking in Fallout 3
#Copyright (C) 2011  Leon N. Maurer

#This program can use a wordlist to check for mispellings in the words entered.
#This should either a text file with one word per line, or a gzipped version of
#that file. If no file is provided, the program will still run.

#The provided word list was copied from /usr/share/dict/words of an Ubuntu
#installation. It is available under the GNU license.

#This program is free software; you can redistribute it and/or
#modify it under the terms of the GNU General Public License
#version 2 as published by the Free Software Foundation;

#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.

#A copy of the license is available at 
#<http://www.gnu.org/licenses/old-licenses/gpl-2.0.html>
#You can also receive a paper copy by writing the Free Software
#Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

#TODO: ADD UNDO ABILITY

require 'tk'
begin #check to see if zlib is installed
  require 'zlib'
rescue Exception
  $useGZ = false
else
  $useGz = true
end

def lettersInCommon(word1, word2)
  word1.split(//).zip(word2.split(//)).inject(0){|sum,c| sum + (c[0] == c[1] ? 1 : 0)}
end

#for error where a word of the wrong lenght is entered
class WordLenghtError < ArgumentError
end

#for when a word not on the wordlist is entered
class SpellingError < ArgumentError
end

#for when a word
class NumberCorrectError < ArgumentError
end

class WordCracker
  attr_reader :words
  
  @@wordList = nil #will hold list of correct words if provided

  def initialize()
    @words = [] #holds the current array of words
#     @oldWords = [] #holds past arrays of words so that we can undo
  end
  
  def wordLength
    @words.size == 0 ? nil : @words[0].length
  end
  
  def rightLength(word)
    (@words.size == 0) or (self.wordLength == word.length)
  end
  
  def add(word, forceSpelling = false)
    if not rightLength(word)
      raise WordLenghtError, "Wrong word length"
    elsif (not forceSpelling) and (not WordCracker.validSpelling(word))
      raise SpellingError, "Word spelling not found"
    else
      @words << word
    end
  end
  
  def remove(word)
    @words.delete(word)
  end
  #this function updates the list after a word is tried and the number of correct letters is found
  def tried(wrongword, correct)
    wordsAfter = @words.reject{|word| (word == wrongword) or (lettersInCommon(word,wrongword) != correct)}
    if wordsAfter.size == 0
      raise NumberCorrectError
    else
      @words = wordsAfter
    end
  end
  
  def suggestWords
    #makes an maxtrix where element i,j is how many letters are in common between word i and word j
    commonMatrix = @words.collect{|word1|
      @words.collect{|word2|
        lettersInCommon(word1,word2)
      }
    }
    #calculate the expected value for how many words will be left after
    #choosing a word, there is one element for each word, and they're in the
    #same order as in @words
    expectedkeep = commonMatrix.collect{|arr|
      #this array will have element n be the number of works that have n
      #letters in common with the word in question
      types = Array.new(self.wordLength,0)
      #don't want to compare word to iteself, so igonre the case when all the
      #letters are in common
      arr.each{|val| types[val] += 1 unless val == self.wordLength}
      #to calculate the expected value for a given word:
      #Pn will be the probability that the word has n correct letters, and Nn
      #will be the number of other words that have n letters in common with our
      #given word. So, for our given word,
      #our expected value = P0*N0 + P1*N1 + P2*N2 + P3*N3 + ...
      #Now, Pn = Nn/(# of oterh words) since each word is equally likely to be
      #the correct word. So, the expected value boils down to:
      #(N0^2 + N1^2 + N3^2 + ...)/(# of other words)
      expectedKeep = types.inject(0.0){|p,num| p + num**2/(@words.size - 1.0)}
    }
    #put words and their expected values together, then sort by the expected keep
    @words.zip(expectedkeep).sort_by{|word,keep| keep}
  end
  #assign the word list as an array. Note that this function handles stripping and upcasing the words in the array.
  def self.wordList=(wordList)
    @@wordList = wordList.collect{|w| w.strip.upcase}
  end
  #check to see if the word is on the wordlist if the list exists
  def self.validSpelling(word)
    (@@wordList == nil) or @@wordList.include?(word)
  end
end

class HackerInterface
  def initialize
    @root = TkRoot.new(){title 'VLHT'}
    @hacker = WordCracker.new
    @wordEntry = TkVariable.new #for the word entry box
    @correctLetters = TkVariable.new #for the number of letters correct entry box
    
    if $useGz and File.exists?("words.gz") #if we have zlib and a gzipped wordlist, use it
      File.open("words.gz") do |f|
	WordCracker.wordList = Zlib::GzipReader.new(f).read.split(/\n/)
      end
    elsif File.exists?("words.txt") #otherwise, check for a non-gzipped list of words
      WordCracker.wordList = File.read("words.txt").split(/\n/)
    end

    #the list of entered words takes up the first row in the interface
    yscroll = proc{|*args| @lbscroll.set(*args)}
    @words = TkVariable.new
    @list = TkListbox.new(@root){
      yscrollcommand yscroll
      height 10
    }.grid(:column=>0,:row=>0,:columnspan=>3,:sticky=>'nsew')
    @list.listvariable(@words)
    
    #the scroll bar that goes with it
    scroll = proc{|*args| @list.yview(*args)}
    @lbscroll = TkScrollbar.new(@root) {
      orient 'vertical'
      command scroll
    }.grid(:column=>4,:row=>0,:sticky=>'wns')

    #this proc handles adding words
    addProc = proc do
      begin
	self.addWord
      rescue WordLenghtError
        Tk.messageBox(
          :type=>'ok',
          :icon=>'error',
          :title=>'Wrong Word Length',
          :message=>'The word you entered is not the same length as the other word(s) in the list.')
      rescue SpellingError
	#find out if it was a spelling error or if that's really the word they want
	self.addWord(true) if 'yes' == Tk.messageBox(
					  :type=>'yesno',
					  :default=>'no',
					  :icon=>'warning',
					  :title=>'Spelling Error',
					  :message=>"That word isn't in my wordlist. It may be mispelled. Should I add it anyway?"
	)
      end
    end
    
    #The next row in the interface is for adding words
    TkLabel.new(@root){
      text 'Word:'
    }.grid('column'=>0, 'row'=>1,'sticky'=>'wns')
    wordEntryBox = TkEntry.new(@root) {
      width 15
      relief  'sunken'
    }.grid(:column=>1,:row=> 1,:sticky=>'w')
    wordEntryBox.textvariable(@wordEntry)
    wordEntryBox.bind("Any-Key-Return", addProc)
    TkButton.new(@root) {
      text    'Add'
      command addProc
    }.grid(:column=>2,:row=>1)

    #the next row in the interface is for updating words
    updateProc = proc{
      begin
	@hacker.tried(self.selectedWord,@correctLetters.value.to_i)
	@correctLetters.value = ''
	self.updateList
      rescue NumberCorrectError
        Tk.messageBox(
          :type=>'ok',
          :icon=>'error',
          :title=>'Wrong Number Correct',
          :message=>'There are no words with that number of correct letters. Either you entered the wrong number, or atleast one word is wrong.')
      end
    }
    TkLabel.new(@root){
      text 'Correct:'
    }.grid(:column=>0,:row=>2,:sticky=>'wns')
    correctLettersBox = TkEntry.new(@root) {
      width 15
      relief  'sunken'
    }.grid(:column=>1,:row=> 2,:sticky=>'w')
    correctLettersBox.textvariable(@correctLetters)
    correctLettersBox.bind("Any-Key-Return", updateProc)
    TkButton.new(@root) {
      text    'Update'
      command updateProc
    }.grid(:column=>2,:row=>2)

    #and the final row in the interface only has a delete button
    removeProc = proc{
      @hacker.remove(self.selectedWord)
      self.updateList
    }
    TkButton.new(@root) {
      text    'Remove'
      command removeProc
    }.grid(:column=>2,:row=>3)

  end
  def updateList
    suggestion = @hacker.suggestWords
    @wordList = suggestion.collect{|word,left| word}
    if @hacker.words.size == 0
      @words.value = ['']
#    elsif @hacker.words.size == 1
#      @words.value = @hacker.words
    else
      @words.value = suggestion.collect{|word,left| "#{word} #{left}"}
    end
  end
  def selectedWord
    #there should be a cleaner way to do the following line
    @wordList[@list.curselection[0].to_i]
  end
  def addWord(force=false)
    @hacker.add(@wordEntry.value.to_s.upcase, force)
    @wordEntry.value = ''
    self.updateList    
  end
end

if __FILE__ == $0
  HackerInterface.new
  Tk.mainloop()
end